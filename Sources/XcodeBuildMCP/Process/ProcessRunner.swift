//
//  ProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// 외부 process 실행을 주입 가능한 경계로 추상화합니다.
package protocol ProcessRunning: Sendable {
	// 요청한 process를 실행하고 표준 출력 및 종료 상태를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult

	// 요청한 process의 표준 출력 조각과 종료 상태를 순서대로 반환합니다.
	func events(for request: ProcessRequest) -> ProcessEventStream
}

extension ProcessRunning {
	// 분할 출력을 지원하지 않는 실행 결과를 단일 출력 사건으로 변환합니다.
	package func events(for request: ProcessRequest) -> ProcessEventStream {
		let taskBox = ProcessEventTaskBox()
		let (stream, continuation) = ProcessEventStream.makeStream(
			maximumBufferedEventCount: 1,
			onTermination: {
				taskBox.cancel()
			}
		)
		let task = Task {
			defer { taskBox.finish() }

			do {
				let result = try await run(request)
				try await continuation.yield(.standardOutput(result.standardOutput))
				try await continuation.yield(.terminated(result.terminationStatus))
				await continuation.finish()
			} catch {
				await continuation.finish(throwing: error)
			}
		}

		taskBox.store(task)
		return stream
	}
}

// 사건 stream Task의 취소와 완료 상태를 보호합니다.
final class ProcessEventTaskBox: @unchecked Sendable {
	private let lock = NSLock()
	private var task: Task<Void, Never>?
	private var isCancelled = false
	private var isFinished = false

	// 취소할 사건 stream Task를 저장합니다.
	func store(_ task: Task<Void, Never>) {
		lock.lock()
		defer { lock.unlock() }

		guard !isFinished else { return }
		self.task = task
		if isCancelled {
			task.cancel()
		}
	}

	// 저장된 Task 또는 이후 저장될 Task를 취소합니다.
	func cancel() {
		lock.lock()
		defer { lock.unlock() }

		isCancelled = true
		task?.cancel()
	}

	// 완료한 Task 보관을 해제합니다.
	func finish() {
		lock.lock()
		defer { lock.unlock() }

		isFinished = true
		task = nil
	}
}
