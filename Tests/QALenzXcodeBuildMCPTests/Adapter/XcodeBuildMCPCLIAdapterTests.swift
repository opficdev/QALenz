//
//  XcodeBuildMCPCLIAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPCLIAdapter의 command 실행과 출력 정규화를 검증합니다.
@Suite
struct XcodeBuildMCPCLIAdapterTests {
	private let operation = XcodeBuildMCPOperation(rawValue: "fixture.list")
	private let discoverSimulatorsOperation = XcodeBuildMCPOperation.discoverSimulators
	private let buildSimulatorOperation = XcodeBuildMCPOperation(rawValue: "build.simulator")

	// 기본 registry가 simulator 목록 JSON 결과를 정규화하는지 검증합니다.
	@Test
	func 기본_registry가_simulator_목록_JSON_결과를_정규화한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)

		let result = await adapter.execute(.init(operation: discoverSimulatorsOperation))

		#expect(result.result == .passed)
		#expect(result.payload == .object([
			"simulators": .array([
				.object([
					"name": .string("Fixture Phone"),
					"simulatorId": .string("fixture-id"),
					"state": .string("Booted"),
					"isAvailable": .boolean(true),
					"runtime": .string("iOS 26.0")
				])
			])
		]))
		#expect(!adapter.supportsEvents(for: discoverSimulatorsOperation))
	}

	// 기본 registry가 build JSON 결과를 통과 결과로 정규화하는지 검증합니다.
	@Test
	func 기본_registry가_build_JSON_결과를_통과_결과로_정규화한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)

		let result = await adapter.execute(.init(
			operation: buildSimulatorOperation,
			arguments: [.init(name: "scheme.name", value: "Fixture")]
		))

		#expect(result.result == .passed)
		#expect(result.payload == .object([
			"summary": .object(["status": .string("SUCCEEDED")])
		]))
	}

	// 기본 registry가 build JSONL terminal event를 완료 사건으로 변환하는지 검증합니다.
	@Test
	func 기본_registry가_build_JSONL_terminal_event를_완료_사건으로_변환한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)
		var events: [XcodeBuildMCPEvent] = []

		for try await event in adapter.events(for: .init(operation: buildSimulatorOperation)) {
			events.append(event)
		}

		#expect(events.map(\.kind) == [.completed])
		#expect(adapter.supportsEvents(for: buildSimulatorOperation))
	}

	// 가짜 CLI의 민감 stderr가 비정상 종료 결과에 복사되지 않는지 검증합니다.
	@Test
	func 가짜_CLI의_민감_stderr가_비정상_종료_결과에_복사되지_않는다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)
		let result = await adapter.execute(.init(
			operation: buildSimulatorOperation,
			arguments: [.init(name: "scheme.name", value: "failure")]
		))
		let error = try #require(result.runError)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	// event를 지원하지 않는 operation이 process를 시작하지 않고 구조화된 오류를 반환하는지 검증합니다.
	@Test
	func event를_지원하지_않는_operation이_구조화된_오류를_반환한다() async throws {
		let runner = ProcessRunnerSpy(output: .success(makeProcessResult("")))
		let adapter = XcodeBuildMCPCLIAdapter(
			processRunner: runner,
			workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
			environment: [:],
			timeout: .seconds(1)
		)
		let stream = adapter.events(for: .init(operation: discoverSimulatorsOperation))

		do {
			for try await _ in stream {}
			Issue.record("지원하지 않는 event operation 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.event.unsupported")
		}

		let processRequest = await runner.receivedRequest

		#expect(processRequest == nil)
	}

	// JSON 실행이 허용된 환경과 working directory로 구성되는지 검증합니다.
	@Test
	func JSON_실행이_허용된_환경과_작업_경로로_구성된다() async {
		let runner = ProcessRunnerSpy(output: .success(makeProcessResult(
			"""
			{"schema":"fixture.output","schemaVersion":"1","didError":false,"error":null,"data":{"items":[]}}
			"""
		)))
		let adapter = makeAdapter(processRunner: runner)
		let request = XcodeBuildMCPRequest(
			operation: operation,
			arguments: [.init(name: "project.root", value: "/tmp/Fixture.xcodeproj")]
		)

		let result = await adapter.execute(request)
		let processRequest = await runner.receivedRequest

		#expect(result.result == .passed)
		#expect(result.payload == .object(["items": .array([])]))
		#expect(processRequest?.arguments == [
			"xcodebuildmcp",
			"simulator",
			"list",
			"--project-path",
			"/tmp/Fixture.xcodeproj",
			"--output",
			"json"
		])
		#expect(processRequest?.workingDirectoryURL == URL(fileURLWithPath: "/tmp"))
		#expect(processRequest?.environment == [
			"PATH": "/usr/bin:/bin",
			"DEVELOPER_DIR": "/Applications/Xcode.app"
		])
	}

	// JSONL 출력이 공통 진행 사건 stream으로 변환되는지 검증합니다.
	@Test
	func JSONL_출력이_공통_진행_사건_stream으로_변환된다() async throws {
		let runner = ProcessRunnerSpy(output: .success(makeProcessResult(
			"""
			{"event":"fixture.progress","operation":"FIXTURE"}
			{"event":"fixture.summary","operation":"FIXTURE","status":"SUCCEEDED"}

			"""
		)))
		let adapter = makeAdapter(processRunner: runner)
		var events: [XcodeBuildMCPEvent] = []

		for try await event in adapter.events(for: .init(operation: operation)) {
			events.append(event)
		}

		let processRequest = await runner.receivedRequest
		#expect(events.map(\.kind) == [.progress, .completed])
		#expect(processRequest?.arguments.suffix(2) == ["--output", "jsonl"])
	}

	// JSONL terminal 사건이 없으면 구조화된 출력 오류로 종료되는지 검증합니다.
	@Test
	func JSONL_terminal_사건이_없으면_출력_오류로_종료한다() async throws {
		let runner = ProcessRunnerSpy(output: .success(makeProcessResult(
			"{\"event\":\"fixture.progress\",\"operation\":\"FIXTURE\"}\n"
		)))
		let stream = makeAdapter(processRunner: runner).events(for: .init(operation: operation))

		do {
			for try await _ in stream {}
			Issue.record("terminal 사건 누락 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
		}
	}

	// 시간 제한 오류가 원본 오류 없이 실행 오류로 변환되는지 검증합니다.
	@Test
	func 시간_제한_오류가_실행_오류로_변환된다() async throws {
		let runner = ProcessRunnerSpy(output: .failure(.timedOut))
		let result = await makeAdapter(processRunner: runner).execute(
			.init(operation: operation)
		)
		let error = try #require(result.runError)

		#expect(error.kind == .execution)
		#expect(error.code.rawValue == "execution.timeout")
	}

	// 비정상 종료 출력이 원본 내용을 결과에 복사하지 않는지 검증합니다.
	@Test
	func 비정상_종료_출력이_원본_내용_없이_오류로_변환된다() async throws {
		let runner = ProcessRunnerSpy(output: .success(.init(
			standardOutput: Data("secret-token-value".utf8),
			terminationStatus: 1
		)))
		let result = await makeAdapter(processRunner: runner).execute(
			.init(operation: operation)
		)
		let error = try #require(result.runError)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	// fixture 구성으로 XcodeBuildMCPCLIAdapter를 생성합니다.
	private func makeAdapter(processRunner: any ProcessRunning) -> XcodeBuildMCPCLIAdapter {
		.init(
			commandBuilder: .init(descriptors: [
				operation: .init(
					workflow: "simulator",
					tool: "list",
					argumentFlags: ["project.root": "--project-path"]
				)
			]),
			outputDecoder: .init(outputDefinitions: [
				operation: [
					"fixture.output": .init(
						versions: ["1"],
						payload: .init(
							isRequired: true,
							schema: .object(
								fields: ["items": .array(element: .scalar)],
								requiredFields: ["items"]
							)
						)
					)
				]
			]),
			eventDescriptors: [operation: .init(namespace: "fixture", operation: "FIXTURE")],
			processRunner: processRunner,
			workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
			environment: [
				"PATH": "/usr/bin:/bin",
				"DEVELOPER_DIR": "/Applications/Xcode.app",
				"SECRET_TOKEN": "secret-token-value"
			],
			timeout: .seconds(1)
		)
	}

	// process runner가 반환할 종료 상태와 출력을 구성합니다.
	private func makeProcessResult(_ output: String) -> ProcessResult {
		.init(standardOutput: Data(output.utf8), terminationStatus: 0)
	}

	// 가짜 xcodebuildmcp 실행 파일을 설치할 임시 디렉터리를 생성합니다.
	private func makeTemporaryDirectory() throws -> URL {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)

		return directory
	}

	// fixture script를 PATH에서 찾을 수 있는 xcodebuildmcp 실행 파일로 설치합니다.
	private func installFakeXcodeBuildMCP(in directory: URL) throws {
		let fixtureURL = try #require(
			Bundle.module.url(forResource: "fake-xcodebuildmcp", withExtension: nil)
		)
		let executableURL = directory.appendingPathComponent("xcodebuildmcp")

		try FileManager.default.copyItem(at: fixtureURL, to: executableURL)
		try FileManager.default.setAttributes(
			[.posixPermissions: 0o755],
			ofItemAtPath: executableURL.path
		)
	}
}

// process 요청을 기록하고 미리 정한 결과를 반환하는 시험 대역입니다.
private actor ProcessRunnerSpy: ProcessRunning {
	private let output: Result<ProcessResult, ProcessRunnerError>
	private var requests: [ProcessRequest] = []

	// 반환 결과로 시험 대역을 구성합니다.
	init(output: Result<ProcessResult, ProcessRunnerError>) {
		self.output = output
	}

	// 요청을 기록하고 결과를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		requests.append(request)
		return try output.get()
	}

	// 처음 기록한 process 요청을 반환합니다.
	var receivedRequest: ProcessRequest? {
		requests.first
	}
}

// 실행 결과에서 정규화된 오류를 꺼냅니다.
private extension XcodeBuildMCPResult {
	// errored 결과의 RunError를 반환합니다.
	var runError: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
