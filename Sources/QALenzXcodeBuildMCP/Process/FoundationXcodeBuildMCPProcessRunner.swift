//
//  FoundationXcodeBuildMCPProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation

// Foundation Process로 XcodeBuildMCP를 실행하고 사건을 전달합니다.
package struct FoundationXcodeBuildMCPProcessRunner: XcodeBuildMCPProcessRunner {
	private typealias ProcessContinuation = AsyncThrowingStream<
		XcodeBuildMCPProcessEvent,
		any Error
	>.Continuation

	// Foundation 기반 process runner를 구성합니다.
	package init() {}

	// 자식 process를 시작하고 stdout 및 종료 사건 stream을 반환합니다.
	package func events(
		for request: XcodeBuildMCPProcessRequest
	) -> AsyncThrowingStream<XcodeBuildMCPProcessEvent, any Error> {
		AsyncThrowingStream { continuation in
			let task = Task {
				await run(request, continuation: continuation)
			}

			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}

	// 자식 process의 실행부터 종료까지 관리하고 continuation을 마무리합니다.
	private func run(
		_ request: XcodeBuildMCPProcessRequest,
		continuation: ProcessContinuation
	) async {
		let process = RunningProcess(request: request)

		do {
			try Task.checkCancellation()
			try process.run()
		} catch is CancellationError {
			continuation.finish(
				throwing: XcodeBuildMCPProcessError.cancelled
			)
			return
		} catch {
			continuation.finish(
				throwing: XcodeBuildMCPProcessError.launchFailed
			)
			return
		}

		let standardOutputTask = makeStandardOutputTask(
			process: process,
			request: request,
			continuation: continuation
		)
		let standardErrorTask = Task.detached { await process.discardStandardError() }

		do {
			let status = try await withTaskCancellationHandler {
				try await waitForExit(process, request: request)
			} onCancel: {
				process.stop(after: request.terminationGracePeriod)
			}

			if Task.isCancelled {
				throw XcodeBuildMCPProcessError.cancelled
			}

			let standardOutputError = await standardOutputTask.value
			_ = await standardErrorTask.value
			if let standardOutputError {
				throw standardOutputError
			}
			continuation.yield(.terminated(status))
			continuation.finish()
		} catch is CancellationError {
			process.stop(after: request.terminationGracePeriod)
			_ = await standardOutputTask.value
			_ = await standardErrorTask.value
			continuation.finish(
				throwing: XcodeBuildMCPProcessError.cancelled
			)
		} catch {
			_ = await standardOutputTask.value
			_ = await standardErrorTask.value
			continuation.finish(throwing: error)
		}
	}

	// stdout을 제한 내에서 전달하는 reader task를 생성합니다.
	private func makeStandardOutputTask(
		process: RunningProcess,
		request: XcodeBuildMCPProcessRequest,
		continuation: ProcessContinuation
	) -> Task<XcodeBuildMCPProcessError?, Never> {
		Task.detached {
			do {
				try await process.readStandardOutput(
					maximumByteCount: request.maximumStandardOutputByteCount
				) { data in
					continuation.yield(.standardOutput(data))
				}

				return nil
			} catch let error as XcodeBuildMCPProcessError {
				process.stop(after: request.terminationGracePeriod)
				return error
			} catch {
				process.stop(after: request.terminationGracePeriod)
				return .launchFailed
			}
		}
	}

	// process 종료와 시간 초과를 함께 감시해 종료 상태를 반환합니다.
	private func waitForExit(
		_ process: RunningProcess,
		request: XcodeBuildMCPProcessRequest
	) async throws -> Int32 {
		let timeoutState = TimeoutState()

		return try await withThrowingTaskGroup(of: WaitOutcome.self) { group in
			group.addTask {
				.terminated(await process.waitUntilExit())
			}
			group.addTask {
				try await Task.sleep(for: request.timeout)
				timeoutState.markTimedOut()
				process.terminate()
				try? await Task.sleep(for: request.terminationGracePeriod)
				process.forceTerminate()

				return .timedOut
			}

			let outcome = try await group.next()
			group.cancelAll()

			if timeoutState.didTimeOut {
				throw XcodeBuildMCPProcessError.timedOut
			}

			switch outcome {
			case let .terminated(status):
				return status
			case .timedOut:
				throw XcodeBuildMCPProcessError.timedOut
			case nil:
				throw XcodeBuildMCPProcessError.launchFailed
			}
		}
	}
}

private extension FoundationXcodeBuildMCPProcessRunner {
	// process 종료 감시 경쟁의 결과를 구분합니다.
	enum WaitOutcome: Sendable {
		case terminated(Int32)
		case timedOut
	}
}

// Foundation Process와 pipe 및 종료 동기화를 함께 관리합니다.
private final class RunningProcess: @unchecked Sendable {
	private let process: Process
	private let standardOutputPipe = Pipe()
	private let standardErrorPipe = Pipe()
	private let blockingQueue = DispatchQueue(
		label: "QALenz.FoundationXcodeBuildMCPProcessRunner.blocking",
		attributes: .concurrent
	)
	private let lock = NSLock()
	private var processGroupIdentifier: pid_t?

	// process 요청을 Foundation Process 설정으로 변환합니다.
	init(request: XcodeBuildMCPProcessRequest) {
		process = Process()
		process.executableURL = request.executableURL
		process.arguments = request.arguments
		process.currentDirectoryURL = request.workingDirectoryURL
		process.environment = request.environment
		process.standardOutput = standardOutputPipe
		process.standardError = standardErrorPipe
	}

	// 구성된 자식 process를 시작합니다.
	func run() throws {
		try process.run()

		let identifier = process.processIdentifier
		let groupIdentifier = Darwin.getpgid(identifier)

		lock.lock()
		if groupIdentifier == identifier {
			processGroupIdentifier = groupIdentifier
		}
		lock.unlock()
	}

	// 자식 process가 끝날 때까지 기다리고 종료 상태를 반환합니다.
	func waitUntilExit() async -> Int32 {
		await withCheckedContinuation { continuation in
			blockingQueue.async {
				self.process.waitUntilExit()
				continuation.resume(
					returning: self.process.terminationStatus
				)
			}
		}
	}

	// stdout을 완료 전까지 읽어 각 data 조각을 전달합니다.
	func readStandardOutput(
		maximumByteCount: Int?,
		_ yield: @escaping @Sendable (Data) -> Void
	) async throws {
		try await withCheckedThrowingContinuation { continuation in
			blockingQueue.async {
				var receivedByteCount = 0

				while true {
					let data = self.standardOutputPipe.fileHandleForReading.availableData

					guard !data.isEmpty else {
						continuation.resume()
						return
					}

					if let maximumByteCount {
						guard
							receivedByteCount <= maximumByteCount,
							data.count <= maximumByteCount - receivedByteCount
						else {
							continuation.resume(
								throwing: XcodeBuildMCPProcessError.standardOutputLimitExceeded
							)
							return
						}
						receivedByteCount += data.count
					}

					yield(data)
				}
			}
		}
	}

	// pipe 정체를 막으면서 stderr 내용을 외부에 노출하지 않고 소비합니다.
	func discardStandardError() async {
		await withCheckedContinuation { continuation in
			blockingQueue.async {
				while true {
					let data = self.standardErrorPipe.fileHandleForReading.availableData

					guard !data.isEmpty else {
						continuation.resume()
						return
					}
				}
			}
		}
	}

	// 정상 종료를 요청한 뒤 유예 시간 이후 강제 종료합니다.
	func stop(after gracePeriod: Duration) {
		terminate()

		Task.detached { [self] in
			try? await Task.sleep(for: gracePeriod)
			forceTerminate()
		}
	}

	// 실행 중인 process에 정상 종료 신호를 보냅니다.
	func terminate() {
		lock.lock()
		defer { lock.unlock() }

		if let processGroupIdentifier {
			Darwin.kill(-processGroupIdentifier, SIGTERM)
		} else if process.isRunning {
			process.terminate()
		}
	}

	// 정상 종료되지 않은 process에 강제 종료 신호를 보냅니다.
	func forceTerminate() {
		lock.lock()
		defer { lock.unlock() }

		if let processGroupIdentifier {
			Darwin.kill(-processGroupIdentifier, SIGKILL)
		} else if process.isRunning {
			Darwin.kill(process.processIdentifier, SIGKILL)
		}
	}
}

// 여러 task가 시간 초과 발생 여부를 안전하게 공유합니다.
private final class TimeoutState: @unchecked Sendable {
	private let lock = NSLock()
	private var timedOut = false

	var didTimeOut: Bool {
		lock.lock()
		defer { lock.unlock() }

		return timedOut
	}

	// 시간 초과 상태를 기록합니다.
	func markTimedOut() {
		lock.lock()
		timedOut = true
		lock.unlock()
	}
}
