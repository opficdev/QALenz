//
//  XcodeBuildMCPCLIAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite(.serialized)
struct XcodeBuildMCPCLIAdapterTests {
	@Test
	func 기본_adapter가_operation별_tool_contract를_사용한다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let recorder = XcodeBuildMCPProcessRequestRecorder()
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: recorder,
			response: .init(
				standardOutput: Data(
					"""
					{"schema":"xcodebuildmcp.output.simulator-list","schemaVersion":"2","didError":false,"error":null,"data":{"simulators":[]}}
					""".utf8
				),
				terminationStatus: 0
			)
		)
		let adapter = XcodeBuildMCPCLIAdapter(
			configuration: makeConfiguration(),
			processRunner: runner
		)

		let result = await adapter.execute(.init(operation: operation))
		let request = try #require(await recorder.requests.first)

		#expect(result.result == .passed)
		#expect(request.arguments.prefix(2) == ["simulator", "list"])
	}

	@Test
	func 주입한_프로세스_실행기가_정제된_설정과_JSON_인자를_받는다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.success")
		let recorder = XcodeBuildMCPProcessRequestRecorder()
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: recorder,
			response: .init(
				standardOutput: successfulEnvelope,
				terminationStatus: 0
			)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "success",
			runner: runner,
			environment: [
				"PATH": "/usr/bin",
				"SECRET_TOKEN": "secret-token-value"
			]
		)

		let result = await adapter.execute(.init(operation: operation))
		let requests = await recorder.requests
		let request = try #require(requests.first)

		#expect(result.result == .passed)
		#expect(request.arguments.suffix(2) == ["--output", "json"])
		#expect(request.environment["PATH"] == "/usr/bin")
		#expect(request.environment["SECRET_TOKEN"] == nil)
	}

	@Test
	func 시험용_실행_파일의_성공_응답이_통과_결과로_변환된다() async {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.success")
		let adapter = makeAdapter(
			operation: operation,
			tool: "success",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)

		let result = await adapter.execute(.init(operation: operation))

		#expect(result.result == .passed)
	}

	@Test
	func 최대_크기를_초과한_JSON_stdout이_구조화된_오류로_변환된다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.success")
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: .init(),
			response: .init(
				standardOutput: Data(repeating: 0x61, count: 33),
				terminationStatus: 0
			)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "success",
			runner: runner,
			maximumJSONByteCount: 32
		)

		let result = await adapter.execute(.init(operation: operation))
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.too-large")
	}

	@Test
	func 실패한_프로세스의_표준_오류가_결과에_노출되지_않는다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.failure")
		let adapter = makeAdapter(
			operation: operation,
			tool: "failure",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)

		let result = await adapter.execute(.init(operation: operation))
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.process.failed")
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	@Test
	func 시험용_실행_파일의_JSONL_출력이_정규화된_이벤트로_전달된다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)
		var events: [XcodeBuildMCPEvent] = []

		for try await event in adapter.events(for: .init(operation: operation)) {
			events.append(event)
		}

		#expect(events.map(\.kind) == [.started, .progress, .completed])
		#expect(events.map(\.message) == [nil, nil, "SUCCEEDED"])
	}

	@Test
	func 완료_summary가_없는_JSONL_stream이_거부된다() async {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: .init(),
			response: .init(standardOutput: Data(), terminationStatus: 0)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: runner
		)

		do {
			for try await _ in adapter.events(for: .init(operation: operation)) {}
			Issue.record("완료 summary가 없는 stream이 거부되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
		} catch {
			Issue.record("구조화되지 않은 오류 반환")
		}
	}

	@Test
	func 느린_소비자에서도_이벤트_buffer가_제한되고_완료_이벤트가_유지된다() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let progressRecords = (0..<5).map { index in
			"""
			{"event":"fixture.progress","operation":"FIXTURE","index":\(index)}
			"""
		}
		let summaryRecord = """
		{"event":"fixture.summary","operation":"FIXTURE","status":"SUCCEEDED"}
		"""
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: .init(),
			response: .init(
				standardOutput: Data(
					(progressRecords + [summaryRecord])
						.joined(separator: "\n")
						.utf8
				),
				terminationStatus: 0
			)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: runner,
			maximumBufferedEventCount: 3
		)
		let stream = adapter.events(for: .init(operation: operation))
		try await Task.sleep(for: .milliseconds(50))
		var events: [XcodeBuildMCPEvent] = []

		for try await event in stream {
			events.append(event)
		}

		#expect(events.count == 3)
		#expect(events.last?.kind == .completed)
	}

	private func makeAdapter(
		operation: XcodeBuildMCPOperation,
		tool: String,
		runner: any XcodeBuildMCPProcessRunner,
		environment: [String: String] = [:],
		maximumJSONByteCount: Int = 1_048_576,
		maximumBufferedEventCount: Int = 64
	) -> XcodeBuildMCPCLIAdapter {
		.init(
			configuration: makeConfiguration(
				environment: environment,
				maximumJSONByteCount: maximumJSONByteCount,
				maximumBufferedEventCount: maximumBufferedEventCount
			),
			contracts: .init(
				commandDescriptors: [
					operation: .init(workflow: "fixture", tool: tool)
				],
				outputContracts: [
					operation: [
						"xcodebuildmcp.output.fixture": .init(
							versions: ["1"],
							payload: .init(
								isRequired: true,
								schema: .object(
									fields: [:],
									requiredFields: []
								)
							)
						)
					]
				],
				eventContracts: [
					operation: .init(namespace: "fixture", operation: "FIXTURE")
				]
			),
			processRunner: runner
		)
	}

	private func makeConfiguration(
		environment: [String: String] = [:],
		maximumJSONByteCount: Int = 1_048_576,
		maximumBufferedEventCount: Int = 64
	) -> XcodeBuildMCPCLIAdapter.Configuration {
		.init(
			executableURL: fakeExecutableURL,
			workingDirectoryURL: FileManager.default.temporaryDirectory,
			environment: environment,
			timeout: .seconds(1),
			terminationGracePeriod: .milliseconds(50),
			maximumJSONByteCount: maximumJSONByteCount,
			maximumBufferedEventCount: maximumBufferedEventCount
		)
	}

	private var fakeExecutableURL: URL {
		Bundle.module.url(
			forResource: "fake-xcodebuildmcp",
			withExtension: nil,
			subdirectory: "Fixtures"
		)!
	}

	private var successfulEnvelope: Data {
		Data(
			"""
			{"schema":"xcodebuildmcp.output.fixture","schemaVersion":"1","didError":false,"error":null,"data":{}}
			""".utf8
		)
	}
}

extension XcodeBuildMCPCLIAdapterTests {
	@Test
	func 두_번째_terminal_이벤트가_거부된다() async {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: .init(),
			response: .init(
				standardOutput: Data(
					"""
					{"event":"fixture.summary","operation":"FIXTURE","status":"FAILED"}
					{"event":"fixture.summary","operation":"FIXTURE","status":"SUCCEEDED"}

					""".utf8
				),
				terminationStatus: 0
			)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: runner
		)
		var events: [XcodeBuildMCPEvent] = []
		do {
			for try await event in adapter.events(for: .init(operation: operation)) {
				events.append(event)
			}
			Issue.record("두 번째 terminal 이벤트가 거부되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
			#expect(events.isEmpty)
		} catch {
			Issue.record("구조화되지 않은 오류 반환")
		}
	}

	@Test
	func nonzero로_종료한_process의_완료_이벤트가_게시되지_않는다() async {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: .init(),
			response: .init(
				standardOutput: Data(
					"""
					{"event":"fixture.summary","operation":"FIXTURE","status":"SUCCEEDED"}

					""".utf8
				),
				terminationStatus: 9
			),
			terminationDelay: .milliseconds(50)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: runner
		)
		var events: [XcodeBuildMCPEvent] = []

		do {
			for try await event in adapter.events(for: .init(operation: operation)) {
				events.append(event)
			}
			Issue.record("실패한 process의 stream이 오류 없이 종료됨")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.process.failed")
			#expect(events.isEmpty)
		} catch {
			Issue.record("구조화되지 않은 오류 반환")
		}
	}
}

private actor XcodeBuildMCPProcessRequestRecorder {
	private(set) var requests: [XcodeBuildMCPProcessRequest] = []

	func record(_ request: XcodeBuildMCPProcessRequest) {
		requests.append(request)
	}
}

private struct XcodeBuildMCPProcessRunnerSpy: XcodeBuildMCPProcessRunner {
	let recorder: XcodeBuildMCPProcessRequestRecorder
	let response: XcodeBuildMCPProcessResponse
	let terminationDelay: Duration?

	// 응답과 선택적인 종료 지연으로 시험용 process runner를 구성합니다.
	init(
		recorder: XcodeBuildMCPProcessRequestRecorder,
		response: XcodeBuildMCPProcessResponse,
		terminationDelay: Duration? = nil
	) {
		self.recorder = recorder
		self.response = response
		self.terminationDelay = terminationDelay
	}

	func events(
		for request: XcodeBuildMCPProcessRequest
	) -> AsyncThrowingStream<XcodeBuildMCPProcessEvent, any Error> {
		AsyncThrowingStream { continuation in
			Task {
				await recorder.record(request)
				continuation.yield(.standardOutput(response.standardOutput))
				if let terminationDelay {
					try? await Task.sleep(for: terminationDelay)
				}
				continuation.yield(.terminated(response.terminationStatus))
				continuation.finish()
			}
		}
	}
}

private extension XcodeBuildMCPResult {
	var error: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
