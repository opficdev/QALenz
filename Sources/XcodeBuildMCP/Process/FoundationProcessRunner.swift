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

	// Foundation Process 실행기를 구성합니다.
	package init() {}

	// process를 실행하고 표준 출력과 종료 상태를 반환합니다.
	package func run(_ request: ProcessRequest) async throws -> ProcessResult {
		guard !Task.isCancelled else {
			throw CancellationError()
		}

		let process = Process()
		let processBox = ProcessBox(process: process)
		let output = Pipe()
		let collector = StandardOutputCollector()

		process.executableURL = request.executableURL
		process.arguments = request.arguments
		process.currentDirectoryURL = request.workingDirectoryURL
		process.environment = request.environment
		process.standardOutput = output
		process.standardError = FileHandle.nullDevice
		output.fileHandleForReading.readabilityHandler = { handle in
			let data = handle.availableData

			guard !data.isEmpty else {
				handle.readabilityHandler = nil
				return
			}

			collector.append(data)
		}

		do {
			try process.run()
		} catch {
			output.fileHandleForReading.readabilityHandler = nil
			throw ProcessRunnerError.failedToLaunch
		}

		guard !Task.isCancelled else {
			processBox.forceTerminate()
			throw CancellationError()
		}

		do {
			try await waitForTermination(processBox, timeout: request.timeout)
		} catch {
			output.fileHandleForReading.readabilityHandler = nil
			collector.append(output.fileHandleForReading.readDataToEndOfFile())
			throw error
		}

		output.fileHandleForReading.readabilityHandler = nil
		collector.append(output.fileHandleForReading.readDataToEndOfFile())

		return .init(
			standardOutput: collector.data,
			terminationStatus: process.terminationStatus
		)
	}

	// 종료, 시간 제한 및 취소 중 먼저 발생한 상태를 처리합니다.
	private func waitForTermination(
		_ process: ProcessBox,
		timeout: Duration
	) async throws {
		let result = await withTaskCancellationHandler {
			await withTaskGroup(of: ProcessWaitResult.self, returning: ProcessWaitResult.self) { group in
				group.addTask {
					process.waitUntilExit()
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

	// process의 종료까지 대기합니다.
	func waitUntilExit() {
		process.waitUntilExit()
	}
}

// 표준 출력 조각을 잠금으로 보호해 누적합니다.
private final class StandardOutputCollector: @unchecked Sendable {
	private let lock = NSLock()
	private var storedData = Data()

	// 새 표준 출력 조각을 누적합니다.
	func append(_ data: Data) {
		guard !data.isEmpty else { return }

		lock.lock()
		defer { lock.unlock() }
		storedData.append(data)
	}

	// 누적된 표준 출력을 반환합니다.
	var data: Data {
		lock.lock()
		defer { lock.unlock() }

		return storedData
	}
}

// process 대기와 시간 제한 대기의 결과를 구분합니다.
private enum ProcessWaitResult: Sendable, Equatable {
	case terminated
	case timedOut
	case cancelled
}
