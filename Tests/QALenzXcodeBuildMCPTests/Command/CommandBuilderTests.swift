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
}
