//
//  FoundationXcodeBuildMCPProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation

package struct FoundationXcodeBuildMCPProcessRunner: XcodeBuildMCPProcessRunner {
	package init() {}

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

	private func run(
		_ request: XcodeBuildMCPProcessRequest,
		continuation: AsyncThrowingStream<
			XcodeBuildMCPProcessEvent,
			any Error
		>.Continuation
	) async {
		let process = RunningProcess(request: request)

		do {
			try process.run()
		} catch {
			continuation.finish(
				throwing: XcodeBuildMCPProcessError.launchFailed
			)
			return
		}

		let standardOutputTask = Task.detached {
			process.readStandardOutput { data in
				continuation.yield(.standardOutput(data))
			}
		}
		let standardErrorTask = Task.detached {
			process.discardStandardError()
		}

		do {
			let status = try await withTaskCancellationHandler {
				try await waitForExit(process, request: request)
			} onCancel: {
				process.stop(after: request.terminationGracePeriod)
			}

			if Task.isCancelled {
				throw XcodeBuildMCPProcessError.cancelled
			}

			_ = await standardOutputTask.value
			_ = await standardErrorTask.value
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

	private func waitForExit(
		_ process: RunningProcess,
		request: XcodeBuildMCPProcessRequest
	) async throws -> Int32 {
		let timeoutState = TimeoutState()

		return try await withThrowingTaskGroup(of: WaitOutcome.self) { group in
			group.addTask {
				.terminated(process.waitUntilExit())
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
	enum WaitOutcome: Sendable {
		case terminated(Int32)
		case timedOut
	}
}

private final class RunningProcess: @unchecked Sendable {
	private let process: Process
	private let standardOutputPipe = Pipe()
	private let standardErrorPipe = Pipe()
	private let lock = NSLock()

	init(request: XcodeBuildMCPProcessRequest) {
		process = Process()
		process.executableURL = request.executableURL
		process.arguments = request.arguments
		process.currentDirectoryURL = request.workingDirectoryURL
		process.environment = request.environment
		process.standardOutput = standardOutputPipe
		process.standardError = standardErrorPipe
	}

	func run() throws {
		try process.run()
	}

	func waitUntilExit() -> Int32 {
		process.waitUntilExit()

		return process.terminationStatus
	}

	func readStandardOutput(
		_ yield: @escaping @Sendable (Data) -> Void
	) {
		while true {
			let data = standardOutputPipe.fileHandleForReading.availableData

			guard !data.isEmpty else { return }

			yield(data)
		}
	}

	func discardStandardError() {
		_ = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
	}

	func stop(after gracePeriod: Duration) {
		terminate()

		Task.detached { [self] in
			try? await Task.sleep(for: gracePeriod)
			forceTerminate()
		}
	}

	func terminate() {
		lock.lock()
		defer { lock.unlock() }

		guard process.isRunning else { return }

		process.terminate()
	}

	func forceTerminate() {
		lock.lock()
		defer { lock.unlock() }

		guard process.isRunning else { return }

		Darwin.kill(process.processIdentifier, SIGKILL)
	}
}

private final class TimeoutState: @unchecked Sendable {
	private let lock = NSLock()
	private var timedOut = false

	var didTimeOut: Bool {
		lock.lock()
		defer { lock.unlock() }

		return timedOut
	}

	func markTimedOut() {
		lock.lock()
		timedOut = true
		lock.unlock()
	}
}
