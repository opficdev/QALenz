//
//  ProcessEventStream.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// 제한된 사건 대기열을 통해 process 출력의 역압을 전달합니다.
package final class ProcessEventStream: AsyncSequence, @unchecked Sendable {
	package typealias Element = ProcessEvent

	private let storage: ProcessEventStreamStorage

	// 소비자가 사건을 순서대로 기다리는 반복자입니다.
	package struct AsyncIterator: AsyncIteratorProtocol {
		private let storage: ProcessEventStreamStorage
		private let cancellation: ProcessEventStreamCancellation

		// 사건을 하나 반환하거나 stream의 종료를 알립니다.
		package mutating func next() async throws -> ProcessEvent? {
			try await storage.next()
		}

		// 사건 대기열과 반복자 취소 처리를 연결합니다.
		fileprivate init(
			storage: ProcessEventStreamStorage,
			cancellation: ProcessEventStreamCancellation
		) {
			self.storage = storage
			self.cancellation = cancellation
		}
	}

	// producer가 사건을 보내고 stream을 종료하는 경계입니다.
	package final class Continuation: @unchecked Sendable {
		private let storage: ProcessEventStreamStorage

		// 제한된 대기열에 사건을 추가합니다.
		package func yield(_ event: ProcessEvent) async throws {
			try await storage.yield(event)
		}

		// 대기 중인 사건 뒤 정상 종료를 전달합니다.
		package func finish() async {
			await storage.finish()
		}

		// 대기 중인 사건을 폐기하고 오류 종료를 전달합니다.
		package func finish(throwing error: any Error) async {
			await storage.finish(throwing: error)
		}

		// 내부 사건 대기열과 연결합니다.
		fileprivate init(storage: ProcessEventStreamStorage) {
			self.storage = storage
		}
	}

	// 제한된 사건 대기열과 producer continuation을 생성합니다.
	package static func makeStream(
		maximumBufferedEventCount: Int,
		onTermination: @escaping @Sendable () -> Void
	) -> (stream: ProcessEventStream, continuation: Continuation) {
		let storage = ProcessEventStreamStorage(
			maximumBufferedEventCount: maximumBufferedEventCount,
			onTermination: onTermination
		)

		return (
			stream: .init(storage: storage),
			continuation: .init(storage: storage)
		)
	}

	// 사건 반복자를 생성합니다.
	package func makeAsyncIterator() -> AsyncIterator {
		.init(
			storage: storage,
			cancellation: .init(storage: storage)
		)
	}

	// 내부 사건 대기열과 연결합니다.
	fileprivate init(storage: ProcessEventStreamStorage) {
		self.storage = storage
	}
}

// 반복자가 중단되면 process 대기를 해제합니다.
private final class ProcessEventStreamCancellation {
	private let storage: ProcessEventStreamStorage

	// 취소할 사건 대기열을 보관합니다.
	init(storage: ProcessEventStreamStorage) {
		self.storage = storage
	}

	deinit {
		let storage = storage
		Task {
			await storage.cancel()
		}
	}
}

// 사건 수를 제한하고 producer와 consumer를 대기시킵니다.
private actor ProcessEventStreamStorage {
	private let maximumBufferedEventCount: Int
	private let onTermination: @Sendable () -> Void
	private var bufferedEvents = [ProcessEvent]()
	private var eventContinuation: CheckedContinuation<ProcessEvent?, any Error>?
	private var capacityContinuations = [CheckedContinuation<Void, any Error>]()
	private var terminationError: (any Error)?
	private var isFinished = false

	// 사건 대기열의 상한과 종료 처리를 구성합니다.
	init(
		maximumBufferedEventCount: Int,
		onTermination: @escaping @Sendable () -> Void
	) {
		precondition(0 < maximumBufferedEventCount)
		self.maximumBufferedEventCount = maximumBufferedEventCount
		self.onTermination = onTermination
	}

	// 대기열에 여유가 생길 때까지 producer를 중단한 뒤 사건을 전달합니다.
	func yield(_ event: ProcessEvent) async throws {
		while true {
			if let terminationError {
				throw terminationError
			}
			guard !isFinished else { return }

			if let eventContinuation {
				self.eventContinuation = nil
				eventContinuation.resume(returning: event)
				return
			}

			guard maximumBufferedEventCount <= bufferedEvents.count else {
				bufferedEvents.append(event)
				return
			}

			try await waitForCapacity()
		}
	}

	// 다음 사건을 반환하거나 producer에 대기열 여유를 알립니다.
	func next() async throws -> ProcessEvent? {
		try Task.checkCancellation()

		if !bufferedEvents.isEmpty {
			let event = bufferedEvents.removeFirst()
			resumeCapacityContinuations()
			return event
		}

		if let terminationError {
			throw terminationError
		}
		guard !isFinished else { return nil }

		return try await withTaskCancellationHandler(operation: {
			try await withCheckedThrowingContinuation { continuation in
				if let terminationError {
					continuation.resume(throwing: terminationError)
				} else if isFinished {
					continuation.resume(returning: nil)
				} else {
					precondition(eventContinuation == nil)
					eventContinuation = continuation
				}
			}
		}, onCancel: {
			Task {
				await self.cancel()
			}
		})
	}

	// 대기 중인 사건 뒤 정상 종료를 반환합니다.
	func finish() {
		guard !isFinished else { return }

		isFinished = true
		resumeCapacityContinuations()

		guard bufferedEvents.isEmpty, let eventContinuation else { return }
		self.eventContinuation = nil
		eventContinuation.resume(returning: nil)
	}

	// 대기 중인 사건을 버리고 오류 종료를 반환합니다.
	func finish(throwing error: any Error) {
		guard !isFinished else { return }

		isFinished = true
		terminationError = error
		bufferedEvents.removeAll(keepingCapacity: false)

		if let eventContinuation {
			self.eventContinuation = nil
			eventContinuation.resume(throwing: error)
		}
		resumeCapacityContinuations(throwing: error)
	}

	// consumer 중단을 process 종료와 사건 대기열 종료로 변환합니다.
	func cancel() {
		guard !isFinished else { return }

		finish(throwing: CancellationError())
		onTermination()
	}

	// producer가 대기열 여유를 기다립니다.
	private func waitForCapacity() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
			if let terminationError {
				continuation.resume(throwing: terminationError)
			} else if isFinished {
				continuation.resume(returning: ())
			} else {
				capacityContinuations.append(continuation)
			}
		}
	}

	// 대기 중인 producer에 대기열 여유를 알립니다.
	private func resumeCapacityContinuations() {
		let capacityContinuations = capacityContinuations
		self.capacityContinuations.removeAll(keepingCapacity: false)

		for continuation in capacityContinuations {
			continuation.resume(returning: ())
		}
	}

	// 대기 중인 producer에 오류 종료를 알립니다.
	private func resumeCapacityContinuations(throwing error: any Error) {
		let capacityContinuations = capacityContinuations
		self.capacityContinuations.removeAll(keepingCapacity: false)

		for continuation in capacityContinuations {
			continuation.resume(throwing: error)
		}
	}
}
