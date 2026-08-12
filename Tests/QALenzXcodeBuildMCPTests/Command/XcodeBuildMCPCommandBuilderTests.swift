//
//  XcodeBuildMCPCommandBuilderTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite
struct XcodeBuildMCPCommandBuilderTests {
	@Test
	func mapsSemanticRequestToJSONCommandArguments() throws {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let builder = XcodeBuildMCPCommandBuilder(descriptors: [
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

	@Test
	func mapsEventRequestToJSONLinesOutput() throws {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let builder = XcodeBuildMCPCommandBuilder(descriptors: [
			operation: .init(workflow: "simulator", tool: "list")
		])
		let request = XcodeBuildMCPRequest(operation: operation)

		let arguments = try builder.arguments(for: request, output: .jsonLines)

		#expect(arguments.suffix(2) == ["--output", "jsonl"])
	}

	@Test
	func rejectsUnsupportedOperationWithoutExposingCommandDetails() {
		let request = XcodeBuildMCPRequest(
			operation: .init(rawValue: "unsupported.operation")
		)
		let builder = XcodeBuildMCPCommandBuilder(descriptors: [:])

		#expect(throws: RunError.self) {
			try builder.arguments(for: request, output: .json)
		}
	}

	@Test
	func rejectsUnsupportedSemanticArgument() {
		let operation = XcodeBuildMCPOperation(rawValue: "discover.simulators")
		let request = XcodeBuildMCPRequest(
			operation: operation,
			arguments: [.init(name: "unknown", value: "value")]
		)
		let builder = XcodeBuildMCPCommandBuilder(descriptors: [
			operation: .init(workflow: "simulator", tool: "list")
		])

		#expect(throws: RunError.self) {
			try builder.arguments(for: request, output: .json)
		}
	}
}
