//
//  DiscoverCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// qalenz discover 명령의 실행과 오류 출력 연결을 검증합니다.
@Suite
struct DiscoverCommandTests {
	// 경로를 생략하면 현재 작업 경로를 project 조회 요청에 전달하는지 검증합니다.
	@Test
	func 경로를_생략하면_현재_작업_경로를_조회한다() async throws {
		let currentDirectoryURL = URL(fileURLWithPath: "/tmp/DiscoverCurrent")
		let adapter = DiscoveryAdapterSpy()
		let command = try discoverCommand()
		let result = await command.execute(
			format: .text,
			adapter: adapter,
			currentDirectoryURL: currentDirectoryURL
		)
		let requests = await adapter.requests()

		#expect(result.exitStatus == .success)
		#expect(requests.first?.arguments == [
			.init(name: "workspace.root", value: currentDirectoryURL.path)
		])
	}

	// 상대 경로와 절대 경로를 표준화해 project 조회 요청에 전달하는지 검증합니다.
	@Test(arguments: [
		("Fixtures/../Project", "/tmp/DiscoverCurrent/Project"),
		("/tmp/DiscoverRoot/../Project", "/tmp/Project")
	])
	func 경로를_표준화해_조회한다(path: String, expectedPath: String) async throws {
		let command = try discoverCommand(path: path)
		let adapter = DiscoveryAdapterSpy()
		let result = await command.execute(
			format: .text,
			adapter: adapter,
			currentDirectoryURL: URL(fileURLWithPath: "/tmp/DiscoverCurrent")
		)
		let requests = await adapter.requests()

		#expect(result.exitStatus == .success)
		#expect(requests.first?.arguments == [
			.init(name: "workspace.root", value: expectedPath)
		])
	}

	// project와 workspace 후보를 text와 JSON 출력으로 반환하는지 검증합니다.
	@Test
	func project와_workspace_후보를_text와_JSON으로_반환한다() async throws {
		let command = try discoverCommand(path: "Fixture")
		let adapter = DiscoveryAdapterSpy()
		let text = await command.execute(
			format: .text,
			adapter: adapter,
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			adapter: DiscoveryAdapterSpy(),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let output = try #require(json.standardOutput?.data(using: .utf8))
		let values = try #require(JSONSerialization.jsonObject(with: output) as? [String: Any])

		#expect(try #require(text.standardOutput).contains("App.xcodeproj"))
		#expect(try #require(text.standardOutput).contains("App.xcworkspace"))
		#expect((values["projects"] as? [[String: String]])?.first?["path"] == "App.xcodeproj")
		#expect((values["workspaces"] as? [[String: String]])?.first?["path"] == "App.xcworkspace")
	}

	// root와 discover 출력 옵션의 우선순위를 유지하는지 검증합니다.
	@Test
	func discover_출력_옵션은_루트_옵션보다_우선한다() throws {
		let rootArguments = ["--output", "json", "discover"]
		let commandArguments = ["--output", "json", "discover", "--output", "text"]
		let rootCommand = try RootCommand.parseAsRoot(rootArguments)
		let commandCommand = try RootCommand.parseAsRoot(commandArguments)
		let rootDiscover = try #require(rootCommand as? DiscoverCommand)
		let commandDiscover = try #require(commandCommand as? DiscoverCommand)

		#expect(CLIApplication.discoverOutputFormat(
			arguments: rootArguments,
			command: rootDiscover
		) == .json)
		#expect(CLIApplication.discoverOutputFormat(
			arguments: commandArguments,
			command: commandDiscover
		) == .text)
	}

	// scheme과 Simulator 오류를 구분해 출력하는지 검증합니다.
	@Test(arguments: [
		XcodeBuildMCPOperation.discoverSchemes,
		XcodeBuildMCPOperation.discoverSimulators
	])
	func 조회_오류를_작업별로_구분한다(operation: XcodeBuildMCPOperation) async throws {
		let adapter = DiscoveryAdapterSpy(failingOperation: operation)
		let command = try discoverCommand(path: "Fixture")
		let text = await command.execute(
			format: .text,
			adapter: adapter,
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			adapter: DiscoveryAdapterSpy(failingOperation: operation),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardError?.data(using: .utf8))
		let result = try JSONDecoder().decode(RunResult.self, from: data)
		let error = try #require(text.standardError)

		#expect(text.exitStatus == .executionError)
		#expect(json.exitStatus == text.exitStatus)
		#expect(error.contains(operation.rawValue))
		#expect(result == .errored(.init(
			kind: .adapter,
			code: .init(rawValue: "adapter.xcodebuildmcp.command.failed"),
			context: .init(command: operation.rawValue)
		)))
		#expect(text.standardOutput == nil)
		#expect(json.standardOutput == nil)
	}

	// 알 수 없는 discovery 오류를 공통 실행 오류로 정규화하는지 검증합니다.
	@Test
	func 알_수_없는_조회_오류를_실행_오류로_정규화한다() async throws {
		let command = try discoverCommand(path: "Fixture")
		let provider = FailingDiscoveryProvider()
		let text = await command.execute(
			format: .text,
			provider: provider,
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			provider: provider,
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardError?.data(using: .utf8))
		let result = try JSONDecoder().decode(RunResult.self, from: data)
		let error = try #require(text.standardError)

		#expect(text.exitStatus == .executionError)
		#expect(json.exitStatus == text.exitStatus)
		#expect(error.contains("execution.discovery.failed"))
		#expect(error.contains("discover"))
		#expect(result == .errored(.init(
			kind: .execution,
			code: .init(rawValue: "execution.discovery.failed"),
			context: .init(command: "discover")
		)))
		#expect(text.standardOutput == nil)
		#expect(json.standardOutput == nil)
	}

	// 경로 인수로 discover 명령을 해석합니다.
	private func discoverCommand(path: String? = nil) throws -> DiscoverCommand {
		var arguments = ["discover"]

		if let path {
			arguments.append(path)
		}

		let command = try RootCommand.parseAsRoot(arguments)

		return try #require(command as? DiscoverCommand)
	}
}

// 알 수 없는 오류를 발생시키는 discovery provider 시험 대역입니다.
private struct FailingDiscoveryProvider: XcodeBuildMCPDiscoveryProviding {
	// RunError가 아닌 오류를 발생시킵니다.
	func discover(at _: URL) async throws -> DiscoveryResult {
		throw CancellationError()
	}
}

// discovery 요청과 응답을 고정하는 XcodeBuildMCP adapter 시험 대역입니다.
private actor DiscoveryAdapterSpy: XcodeBuildMCPAdapter {
	private let failingOperation: XcodeBuildMCPOperation?
	private var receivedRequests: [XcodeBuildMCPRequest] = []

	// 선택한 작업의 실패 여부로 시험 대역을 초기화합니다.
	init(failingOperation: XcodeBuildMCPOperation? = nil) {
		self.failingOperation = failingOperation
	}

	// 요청을 기록하고 작업에 맞는 고정 결과를 반환합니다.
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		receivedRequests.append(request)

		if request.operation == failingOperation {
			return .init(
				operation: request.operation,
				result: .errored(.init(
					kind: .adapter,
					code: .init(rawValue: "adapter.xcodebuildmcp.command.failed"),
					context: .init(command: request.operation.rawValue)
				))
			)
		}

		return switch request.operation {
		case .discoverProjects:
			projectResult()
		case .discoverSchemes:
			schemeResult()
		case .discoverSimulators:
			simulatorResult()
		default:
			.init(operation: request.operation, result: .failed)
		}
	}

	// 사용하지 않는 진행 사건 stream을 반환합니다.
	nonisolated func events(
		for _: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		.init { $0.finish() }
	}

	// 기록한 요청을 반환합니다.
	func requests() -> [XcodeBuildMCPRequest] {
		receivedRequests
	}

	// project와 workspace 후보 payload를 반환합니다.
	private func projectResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverProjects,
			result: .passed,
			payload: .object([
				"projects": .array([.object(["path": .string("App.xcodeproj")])]),
				"workspaces": .array([.object(["path": .string("App.xcworkspace")])])
			])
		)
	}

	// scheme 후보 payload를 반환합니다.
	private func schemeResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverSchemes,
			result: .passed,
			payload: .object(["schemes": .array([.string("App")])])
		)
	}

	// Simulator 후보 payload를 반환합니다.
	private func simulatorResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverSimulators,
			result: .passed,
			payload: .object([
				"simulators": .array([.object([
					"name": .string("iPhone 17"),
					"simulatorId": .string("simulator-id"),
					"state": .string("Shutdown"),
					"runtime": .string("iOS 26.0"),
					"isAvailable": .boolean(true)
				])])
			])
		)
	}
}
