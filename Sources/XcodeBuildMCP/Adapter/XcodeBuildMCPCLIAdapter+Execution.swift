//
//  XcodeBuildMCPCLIAdapter+Execution.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import QALenzCore

// build-and-run JSONL process를 단일 실행 수명주기로 변환합니다.
extension XcodeBuildMCPCLIAdapter {
	// 하나의 JSONL process에서 진행 사건과 terminal 결과를 함께 전달합니다.
	package func execution(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPExecutionUpdate, any Error> {
		.init { continuation in
			let task = Task {
				do {
					let result = try await executeJSONLines(request, continuation: continuation)
					continuation.yield(.completed(result))
					continuation.finish()
				} catch {
					continuation.finish(throwing: normalizedError(operation: request.operation, error: error))
				}
			}

			continuation.onTermination = { @Sendable _ in task.cancel() }
		}
	}

	// 단일 JSONL process의 진행 사건과 종료 상태를 읽어 terminal 결과를 구성합니다.
	private func executeJSONLines(
		_ request: XcodeBuildMCPRequest,
		continuation: AsyncThrowingStream<XcodeBuildMCPExecutionUpdate, any Error>.Continuation
	) async throws -> XcodeBuildMCPResult {
		guard let descriptor = eventDescriptors[request.operation] else {
			throw failureError(
				operation: request.operation,
				kind: .adapter,
				code: "adapter.xcodebuildmcp.event.unsupported"
			)
		}

		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)
		var outcome = BuildAndRunOutcome()
		var terminationStatus: Int32?
		let commandRequest = try processRequest(for: request, output: .jsonLines)
		for try await processEvent in processRunner.events(for: commandRequest) {
			switch processEvent {
			case let .standardOutput(data):
				outcome.consume(data)
				for event in try decoder.decode(data, operation: request.operation) {
					outcome.didReceiveEvent = true
					continuation.yield(.event(event))
				}
			case let .terminated(status):
				terminationStatus = status
			}
		}
		guard let terminationStatus else {
			throw failureError(
				operation: request.operation,
				kind: .adapter,
				code: "adapter.xcodebuildmcp.process.failed"
			)
		}
		for event in try decoder.finish(operation: request.operation) {
			outcome.didReceiveEvent = true
			continuation.yield(.event(event))
		}
		guard outcome.didReceiveEvent else {
			throw failureError(
				operation: request.operation,
				kind: .adapter,
				code: "adapter.xcodebuildmcp.output.invalid"
			)
		}

		return .init(
			operation: request.operation,
			result: terminalResult(
				for: terminationStatus,
				outcome: outcome,
				operation: request.operation
			)
		)
	}

	// JSONL phase와 process 종료 상태를 run 결과로 정규화합니다.
	private func terminalResult(
		for status: Int32,
		outcome: BuildAndRunOutcome,
		operation: XcodeBuildMCPOperation
	) -> RunResult {
		guard status != 0 else { return .passed }
		guard status != Self.commandNotFoundStatus else {
			return .errored(terminationError(operation: operation, status: status))
		}

		let code = outcome.didReachRunPhase
			? "execution.launch.failed"
			: "execution.build.failed"
		return .errored(failureError(operation: operation, kind: .execution, code: code))
	}
}

// build-and-run JSONL에서 오류 분류에 필요한 phase만 보관합니다.
private struct BuildAndRunOutcome {
	private var buffer = Data()
	var didReceiveEvent = false
	private(set) var didReachRunPhase = false

	mutating func consume(_ data: Data) {
		buffer.append(data)

		while let newline = buffer.firstIndex(of: 0x0A) {
			let line = buffer[..<newline]
			buffer.removeSubrange(...newline)
			recordPhase(in: Data(line))
		}
	}

	private mutating func recordPhase(in data: Data) {
		guard let event = try? JSONDecoder().decode(Event.self, from: data) else {
			return
		}
		guard event.event == "build-run-result.phase" else {
			return
		}
		guard event.phase != nil else {
			return
		}

		didReachRunPhase = true
	}

	private struct Event: Decodable {
		let event: String
		let phase: String?
	}
}
