//
//  ProcessEventEmitter.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// 표준 출력 읽기와 process 사건 완료 순서를 직렬화합니다.
final class ProcessEventEmitter: @unchecked Sendable {
	private let continuation: ProcessEventStream.Continuation
	private let standardOutputHandle: FileHandle
	private let maximumStandardOutputChunkByteCount: Int
	private let queue = DispatchQueue(label: "QALenz.FoundationProcessRunner.ProcessEventEmitter")
	private var isDelivering = false
	private var isFinishing = false
	private var isFinished = false
	private var terminationStatus: Int32?
	private var finishContinuations = [CheckedContinuation<Void, Never>]()

	// 사건 stream과 제한된 표준 출력 조각 크기를 구성합니다.
	init(
		continuation: ProcessEventStream.Continuation,
		standardOutputHandle: FileHandle,
		maximumStandardOutputChunkByteCount: Int
	) {
		precondition(0 < maximumStandardOutputChunkByteCount)
		self.continuation = continuation
		self.standardOutputHandle = standardOutputHandle
		self.maximumStandardOutputChunkByteCount = maximumStandardOutputChunkByteCount
	}

	// 표준 출력 수신 대기를 시작합니다.
	func start() {
		queue.sync {
			installReadabilityHandler()
		}
	}

	// 현재 읽을 수 있는 표준 출력 조각의 전달을 시작합니다.
	func emitAvailableData() {
		standardOutputHandle.readabilityHandler = nil
		queue.async {
			self.deliverNextEvent()
		}
	}

	// 남은 표준 출력과 종료 상태를 순서대로 전달합니다.
	func finish(terminationStatus: Int32) async {
		await withCheckedContinuation { continuation in
			queue.async {
				guard !self.isFinished else {
					continuation.resume()
					return
				}

				self.standardOutputHandle.readabilityHandler = nil
				self.isFinishing = true
				self.terminationStatus = terminationStatus
				self.finishContinuations.append(continuation)
				self.deliverNextEvent()
			}
		}
	}

	// 원본 오류로 stream을 종료합니다.
	func finish(throwing error: any Error) async {
		await withCheckedContinuation { completion in
			queue.async {
				guard !self.isFinished else {
					completion.resume()
					return
				}

				self.standardOutputHandle.readabilityHandler = nil
				self.isFinished = true
				self.completeFinishing()
				Task {
					await self.continuation.finish(throwing: error)
					completion.resume()
				}
			}
		}
	}

	// 대기열에 여유가 생길 때까지 한 표준 출력 조각을 전달합니다.
	private func deliverNextEvent() {
		guard !isFinished, !isDelivering else { return }

		let data = StandardOutputDrainer.readBufferedData(
			from: standardOutputHandle,
			maximumByteCount: maximumStandardOutputChunkByteCount
		)
		if !data.isEmpty {
			deliverStandardOutput(data)
			return
		}

		if let terminationStatus {
			deliverTermination(terminationStatus)
		} else if !isFinishing {
			installReadabilityHandler()
		}
	}

	// 표준 출력 조각이 consumer에 전달될 때까지 대기합니다.
	private func deliverStandardOutput(_ data: Data) {
		isDelivering = true

		Task {
			try? await continuation.yield(.standardOutput(data))
			queue.async {
				self.isDelivering = false
				self.deliverNextEvent()
			}
		}
	}

	// 종료 상태를 한 번 전달한 뒤 stream을 완료합니다.
	private func deliverTermination(_ terminationStatus: Int32) {
		isDelivering = true

		Task {
			if (try? await continuation.yield(.terminated(terminationStatus))) != nil {
				await continuation.finish()
			}
			queue.async {
				self.isDelivering = false
				self.isFinished = true
				self.completeFinishing()
			}
		}
	}

	// 읽을 표준 출력이 생기면 전달을 시작할 handler를 연결합니다.
	private func installReadabilityHandler() {
		guard !isFinished, !isFinishing, !isDelivering else { return }

		standardOutputHandle.readabilityHandler = { [weak self] _ in
			self?.emitAvailableData()
		}
	}

	// 정상 종료를 기다리는 호출을 완료합니다.
	private func completeFinishing() {
		let finishContinuations = finishContinuations
		self.finishContinuations.removeAll(keepingCapacity: false)

		for continuation in finishContinuations {
			continuation.resume()
		}
	}
}
