//
//  CLIAdapterTerminalEventTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPCLIAdapter의 terminal 사건 전달 조건을 검증합니다.
@Suite
struct CLIAdapterTerminalEventTests {
	private let operation = XcodeBuildMCPOperation(rawValue: "fixture.list")

	// 비정상 종료한 JSONL 실행이 completed 사건을 먼저 전달하지 않는지 검증합니다.
	@Test
	func 비정상_종료한_JSONL_실행이_completed_사건을_전달하지_않는다() async throws {
		let runner = TerminalEventProcessRunnerStub(result: .init(
			standardOutput: Data(
				"{\"event\":\"fixture.summary\",\"operation\":\"FIXTURE\",\"status\":\"SUCCEEDED\"}\n".utf8
			),
			terminationStatus: 1
		))
		let stream = makeAdapter(processRunner: runner).events(for: .init(operation: operation))
		var events = [XcodeBuildMCPEvent]()

		do {
			for try await event in stream {
				events.append(event)
			}
			Issue.record("비정상 종료 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		}

		#expect(!events.contains { $0.kind == .completed })
	}

	// terminal 사건 시험 구성으로 adapter를 생성합니다.
	private func makeAdapter(processRunner: any ProcessRunning) -> XcodeBuildMCPCLIAdapter {
		.init(
			commandBuilder: .init(descriptors: [
				operation: .init(
					workflow: "simulator",
					tool: "list",
					argumentFlags: [:]
				)
			]),
			outputDecoder: .init(outputDefinitions: [:]),
			eventDescriptors: [operation: .init(namespace: "fixture", operation: "FIXTURE")],
			processRunner: processRunner,
			workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
			environment: [:],
			timeout: .seconds(1)
		)
	}
}

// 정해진 process 결과를 반환하는 terminal 사건 시험 대역입니다.
private struct TerminalEventProcessRunnerStub: ProcessRunning {
	let result: ProcessResult

	// process 결과를 그대로 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		result
	}
}
