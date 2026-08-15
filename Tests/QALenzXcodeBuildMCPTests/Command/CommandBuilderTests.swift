//
//  CommandBuilderTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// CommandBuilder 변환 계약을 검증합니다.
@Suite
struct CommandBuilderTests {
	// discovery 요청이 project-discovery CLI argument로 변환되는지 검증합니다.
	@Test
	func discovery_요청이_project_discovery_CLI_인자로_변환된다() throws {
		let projectArguments = try XcodeBuildMCPV2.commandBuilder.arguments(
			for: .init(
				operation: .discoverProjects,
				arguments: [.init(name: "workspace.root", value: "/tmp/Fixture")]
			),
			output: .json
		)
		let schemeArguments = try XcodeBuildMCPV2.commandBuilder.arguments(
			for: .init(
				operation: .discoverSchemes,
				arguments: [.init(name: "project.path", value: "/tmp/Fixture.xcodeproj")]
			),
			output: .json
		)

		#expect(projectArguments == [
			"project-discovery",
			"discover-projects",
			"--workspace-root",
			"/tmp/Fixture",
			"--output",
			"json"
		])
		#expect(schemeArguments == [
			"project-discovery",
			"list-schemes",
			"--project-path",
			"/tmp/Fixture.xcodeproj",
			"--output",
			"json"
		])
	}

	// discovery 요청의 필수 경로 argument가 없으면 거부되는지 검증합니다.
	@Test(arguments: [
		XcodeBuildMCPRequest(operation: .discoverProjects),
		.init(operation: .discoverSchemes)
	])
	func discovery_요청에_필수_경로_argument가_없으면_거부한다(
		_ request: XcodeBuildMCPRequest
	) throws {
		let error = try requireRunError {
			try XcodeBuildMCPV2.commandBuilder.arguments(for: request, output: .json)
		}

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.argument.unsupported")
	}

	// scheme 조회 요청에 project와 workspace 경로를 함께 전달하면 거부되는지 검증합니다.
	@Test
	func scheme_조회_요청에_상호_배타적인_경로를_함께_전달하면_거부한다() throws {
		let request = XcodeBuildMCPRequest(
			operation: .discoverSchemes,
			arguments: [
				.init(name: "project.path", value: "/tmp/Fixture.xcodeproj"),
				.init(name: "workspace.path", value: "/tmp/Fixture.xcworkspace")
			]
		)

		let error = try requireRunError {
			try XcodeBuildMCPV2.commandBuilder.arguments(for: request, output: .json)
		}

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.argument.unsupported")
	}

	// 의미 기반 요청이 JSON CLI argument로 변환되는지 검증합니다.
	@Test
	func 의미_기반_요청이_JSON_명령_인자로_변환된다() throws {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let builder = CommandBuilder(descriptors: [
			operation: .init(
				workflow: "simulator",
				tool: "list",
				argumentFlags: ["project.root": "--project-path"]
			)
		])
		let request = XcodeBuildMCPRequest(
			operation: operation,
			arguments: [
				.init(name: "project.root", value: "/tmp/Fixture.xcodeproj")
			]
		)

		let arguments = try builder.arguments(for: request, output: .json)

		#expect(arguments == [
			"simulator",
			"list",
			"--project-path",
			"/tmp/Fixture.xcodeproj",
			"--output",
			"json"
		])
	}

	// 사건 요청이 JSONL 출력 형식을 사용하는지 검증합니다.
	@Test
	func 이벤트_요청이_JSONL_출력을_사용한다() throws {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let builder = CommandBuilder(descriptors: [
			operation: .init(workflow: "simulator", tool: "list")
		])
		let request = XcodeBuildMCPRequest(operation: operation)

		let arguments = try builder.arguments(for: request, output: .jsonLines)

		#expect(arguments.suffix(2) == ["--output", "jsonl"])
	}

	// UI automation 요청이 XcodeBuildMCP CLI argument로 변환되는지 검증합니다.
	@Test
	func UI_automation_요청이_CLI_인자로_변환된다() throws {
		let arguments = try XcodeBuildMCPV2.commandBuilder.arguments(
			for: .init(
				operation: .swipeUI,
				arguments: [
					.init(name: "profile", value: "fixture"),
					.init(name: "element.reference", value: "e4"),
					.init(name: "direction", value: "down"),
					.init(name: "duration.seconds", value: "0.5"),
					.init(name: "distance", value: "0.8")
				]
			),
			output: .json
		)

		#expect(arguments == [
			"ui-automation",
			"swipe",
			"--profile",
			"fixture",
			"--within-element-ref",
			"e4",
			"--direction",
			"down",
			"--duration",
			"0.5",
			"--distance",
			"0.8",
			"--output",
			"json"
		])
	}

	// 지원하지 않는 operation이 구조화된 오류로 거부되는지 검증합니다.
	@Test
	func 지원하지_않는_작업이_명령_정보_노출_없이_거부된다() {
		let request = XcodeBuildMCPRequest(
			operation: .init(rawValue: "unsupported.operation")
		)
		let builder = CommandBuilder(descriptors: [:])

		#expect(throws: RunError.self) {
			try builder.arguments(for: request, output: .json)
		}
	}

	// descriptor에 없는 의미 기반 argument가 거부되는지 검증합니다.
	@Test
	func 작업_설명에_없는_의미_기반_인자가_거부된다() {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let request = XcodeBuildMCPRequest(
			operation: operation,
			arguments: [.init(name: "unknown", value: "value")]
		)
		let builder = CommandBuilder(descriptors: [
			operation: .init(workflow: "simulator", tool: "list")
		])

		#expect(throws: RunError.self) {
			try builder.arguments(for: request, output: .json)
		}
	}

	// builder가 던진 RunError를 반환합니다.
	private func requireRunError(
		from operation: () throws -> [String]
	) throws -> RunError {
		try #require(throws: RunError.self) {
			try operation()
		}
	}
}
