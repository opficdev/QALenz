//
//  FoundationProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Darwin
import Foundation

// Foundation Process로 외부 command를 실행하고 취소 및 시간 제한 시 종료합니다.
package final class FoundationProcessRunner: ProcessRunning, @unchecked Sendable {
	private static let terminationGracePeriod = Duration.milliseconds(100)
	private static let maximumBufferedStandardOutputChunkCount = 4
	private static let maximumStandardOutputChunkByteCount = 16 * 1024

	private let maximumBufferedStandardOutputChunkCount: Int

	// 기본 표준 출력 대기열 상한으로 Foundation Process 실행기를 구성합니다.
	package convenience init() {
		self.init(
			maximumBufferedStandardOutputChunkCount: Self.maximumBufferedStandardOutputChunkCount
		)
	}

	// 지정한 표준 출력 대기열 상한으로 Foundation Process 실행기를 구성합니다.
	package init(maximumBufferedStandardOutputChunkCount: Int) {
		precondition(0 < maximumBufferedStandardOutputChunkCount)
		self.maximumBufferedStandardOutputChunkCount = maximumBufferedStandardOutputChunkCount
	}

	// process를 실행하고 표준 출력과 종료 상태를 반환합니다.
	package func run(_ request: ProcessRequest) async throws -> ProcessResult {
		guard !Task.isCancelled else {
			throw CancellationError()
		}
		try validateLaunchRequest(request)

		let process = Process()
		let processBox = ProcessBox(process: process)
		let termination = ProcessTerminationObserver(process: process)
		let output = Pipe()
		let collector = StandardOutputCollector()

		process.executableURL = request.executableURL
		process.arguments = request.arguments
		process.currentDirectoryURL = request.workingDirectoryURL
		process.environment = request.environment
		process.standardOutput = output
		process.standardError = FileHandle.nullDevice
		output.fileHandleForReading.readabilityHandler = { collector.collectAvailableData(from: $0) }

		do {
			try process.run()
		} catch {
			output.fileHandleForReading.readabilityHandler = nil
			throw preflightError(for: request) ?? .failedToLaunch
		}

		guard !Task.isCancelled else {
			processBox.forceTerminate()
			throw CancellationError()
		}

		do {
			try await waitForTermination(
				processBox,
				termination: termination,
				timeout: request.timeout
			)
		} catch {
			output.fileHandleForReading.readabilityHandler = nil
			try? output.fileHandleForReading.close()
			throw error
		}

		output.fileHandleForReading.readabilityHandler = nil
		let standardOutput = collector.finishCollecting(from: output.fileHandleForReading)
		try? output.fileHandleForReading.close()

		return .init(
			standardOutput: standardOutput,
			terminationStatus: process.terminationStatus
		)
	}

	// process의 표준 출력 조각을 종료 전부터 순서대로 반환합니다.
	package func events(for request: ProcessRequest) -> ProcessEventStream {
		let process = Process()
		let processBox = ProcessBox(process: process)
		let termination = ProcessTerminationObserver(process: process)
		let output = Pipe()
		let (stream, continuation) = ProcessEventStream.makeStream(
			maximumBufferedEventCount: maximumBufferedStandardOutputChunkCount,
			onTermination: {
				processBox.forceTerminate()
			}
		)
		let emitter = ProcessEventEmitter(
			continuation: continuation,
			standardOutputHandle: output.fileHandleForReading,
			maximumStandardOutputChunkByteCount: Self.maximumStandardOutputChunkByteCount
		)

		process.executableURL = request.executableURL
		process.arguments = request.arguments
		process.currentDirectoryURL = request.workingDirectoryURL
		process.environment = request.environment
		process.standardOutput = output
		process.standardError = FileHandle.nullDevice
		emitter.start()

		Task {
			do {
				try Task.checkCancellation()
				try validateLaunchRequest(request)

				do {
					try process.run()
				} catch {
					throw preflightError(for: request) ?? .failedToLaunch
				}

				guard !Task.isCancelled else {
					processBox.forceTerminate()
					throw CancellationError()
				}

				try await waitForTermination(
					processBox,
					termination: termination,
					timeout: request.timeout
				)
				await emitter.finish(terminationStatus: process.terminationStatus)
				try? output.fileHandleForReading.close()
			} catch {
				await emitter.finish(throwing: error)
				try? output.fileHandleForReading.close()
			}
		}

		return stream
	}

	// 실행 요청이 시작 가능한 경로를 가지는지 검증합니다.
	private func validateLaunchRequest(_ request: ProcessRequest) throws {
		if let error = preflightError(for: request) {
			throw error
		}
	}

	// 실행 파일과 작업 경로의 시작 가능 여부를 반환합니다.
	private func preflightError(for request: ProcessRequest) -> ProcessRunnerError? {
		guard FileManager.default.isExecutableFile(atPath: request.executableURL.path) else {
			return .executableUnavailable
		}

		var isDirectory = ObjCBool(false)
		guard FileManager.default.fileExists(
			atPath: request.workingDirectoryURL.path,
			isDirectory: &isDirectory
		), isDirectory.boolValue else {
			return .invalidWorkingDirectory
		}

		return nil
	}

	// 종료, 시간 제한 및 취소 중 먼저 발생한 상태를 처리합니다.
	private func waitForTermination(
		_ process: ProcessBox,
		termination: ProcessTerminationObserver,
		timeout: Duration
	) async throws {
		let result = await withTaskCancellationHandler {
			await withTaskGroup(of: ProcessWaitResult.self, returning: ProcessWaitResult.self) { group in
				group.addTask {
					await termination.wait()
					return .terminated
				}
				group.addTask {
					do {
						try await Task.sleep(for: timeout)
						return .timedOut
					} catch {
						return .cancelled
					}
				}

				let result = await group.next() ?? .cancelled
				if result == .timedOut {
					process.terminate()
					group.addTask {
						do {
							try await Task.sleep(for: Self.terminationGracePeriod)
							return .timedOut
						} catch {
							return .cancelled
						}
					}

					let terminationResult = await group.next() ?? .cancelled
					if terminationResult != .terminated {
						process.forceTerminate()
					}
				} else if result == .cancelled {
					process.forceTerminate()
				}
				group.cancelAll()

				return result
			}
		} onCancel: {
			process.forceTerminate()
		}

		guard !Task.isCancelled else {
			throw CancellationError()
		}

		switch result {
		case .terminated:
			return
		case .timedOut:
			throw ProcessRunnerError.timedOut
		case .cancelled:
			throw CancellationError()
		}
	}
}

// Process의 종료와 종료 요청을 동시 접근으로부터 보호합니다.
private final class ProcessBox: @unchecked Sendable {
	private let process: Process
	private let lock = NSLock()

	// 종료를 제어할 Foundation Process를 보관합니다.
	init(process: Process) {
		self.process = process
	}

	// process가 실행 중이면 종료 요청을 보냅니다.
	func terminate() {
		lock.lock()
		defer { lock.unlock() }

		guard process.isRunning else { return }

		process.terminate()
	}

	// process가 실행 중이면 강제 종료 신호를 보냅니다.
	func forceTerminate() {
		lock.lock()
		defer { lock.unlock() }

		guard process.isRunning else { return }

		_ = kill(process.processIdentifier, SIGKILL)
	}
}

// Process 종료 알림을 비차단 대기로 변환합니다.
private final class ProcessTerminationObserver: @unchecked Sendable {
	private let lock = NSLock()
	private var isTerminated = false
	private var continuations = [CheckedContinuation<Void, Never>]()

	// 종료를 관찰할 Process에 handler를 연결합니다.
	init(process: Process) {
		process.terminationHandler = { [weak self] _ in
			self?.resumeWaiters()
		}
	}

	// Process 종료까지 현재 Task를 중단합니다.
	func wait() async {
		await withCheckedContinuation { continuation in
			lock.lock()
			guard !isTerminated else {
				lock.unlock()
				continuation.resume()
				return
			}

			continuations.append(continuation)
			lock.unlock()
		}
	}

	// 대기 중인 모든 Task에 Process 종료를 알립니다.
	private func resumeWaiters() {
		lock.lock()
		guard !isTerminated else {
			lock.unlock()
			return
		}

		isTerminated = true
		let waiters = continuations
		continuations.removeAll(keepingCapacity: false)
		lock.unlock()

		for waiter in waiters {
			waiter.resume()
		}
	}
}

// 표준 출력 조각을 잠금으로 보호해 누적합니다.
private final class StandardOutputCollector: @unchecked Sendable {
	private let lock = NSLock()
	private var storedData = Data()
	private var isFinished = false

	// 현재 읽을 수 있는 표준 출력 조각을 누적합니다.
	func collectAvailableData(from handle: FileHandle) {
		lock.lock()
		defer { lock.unlock() }
		guard !isFinished else { return }

		let data = handle.availableData
		guard !data.isEmpty else {
			handle.readabilityHandler = nil
			return
		}

		storedData.append(data)
	}

	// 남은 buffer를 누적한 뒤 전체 표준 출력을 반환합니다.
	func finishCollecting(from handle: FileHandle) -> Data {
		lock.lock()
		defer { lock.unlock() }
		guard !isFinished else { return storedData }
		isFinished = true

		storedData.append(StandardOutputDrainer.drainBufferedData(from: handle))

		return storedData
	}
}

// process 대기와 시간 제한 대기의 결과를 구분합니다.
private enum ProcessWaitResult: Sendable, Equatable {
	case terminated
	case timedOut
	case cancelled
}
