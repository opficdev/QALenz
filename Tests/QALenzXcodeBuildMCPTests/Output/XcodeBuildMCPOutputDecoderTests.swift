//
//  XcodeBuildMCPOutputDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite
struct XcodeBuildMCPOutputDecoderTests {
	private let operation = XcodeBuildMCPOperation(
		rawValue: "discover.simulators"
	)

	@Test
	func 지원하는_성공_응답이_통과_결과로_변환된다() throws {
		let decoder = makeDecoder()
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "2",
			"didError": false,
			"error": null,
			"data": {"simulators": []},
			"nextSteps": ["xcodebuildmcp simulator build"]
		}
		"""

		let result = decoder.decode(Data(json.utf8), operation: operation)
		let envelope = try decoder.decodeEnvelope(Data(json.utf8))

		#expect(result.result == .passed)
		#expect(envelope.nextSteps == ["xcodebuildmcp simulator build"])
	}

	@Test
	func 성공_응답의_payload가_결과에_보존된다() {
		let decoder = makeDecoder()
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "2",
			"didError": false,
			"error": null,
			"data": {"simulators": []}
		}
		"""

		let result = decoder.decode(Data(json.utf8), operation: operation)

		#expect(result.payload == .object(["simulators": .array([])]))
	}

	@Test
	func 도구_실패가_원본_오류_내용_없이_정규화된다() throws {
		let decoder = makeDecoder()
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "2",
			"didError": true,
			"error": "secret-token-value",
			"data": {"simulators": []}
		}
		"""

		let result = decoder.decode(Data(json.utf8), operation: operation)
		let error = try #require(result.error)

		#expect(error.kind == .adapter)
		#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		#expect(error.context.command == operation.rawValue)
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	@Test
	func 잘못된_JSON이_구조화된_출력_오류로_변환된다() throws {
		let result = makeDecoder().decode(
			Data("{malformed".utf8),
			operation: operation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	@Test
	func 지원하지_않는_응답_형식_버전이_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "99",
			"didError": false,
			"error": null,
			"data": {"simulators": []}
		}
		"""

		let result = makeDecoder().decode(
			Data(json.utf8),
			operation: operation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.schema.unsupported")
	}

	@Test
	func 다른_operation의_응답_schema가_거부된다() throws {
		let buildOperation = XcodeBuildMCPOperation(rawValue: "build.simulator")
		let decoder = XcodeBuildMCPOutputDecoder(supportedSchemaVersions: [
			operation: ["xcodebuildmcp.output.simulator-list": ["2"]],
			buildOperation: ["xcodebuildmcp.output.build-result": ["3"]]
		])
		let json = """
		{
			"schema": "xcodebuildmcp.output.build-result",
			"schemaVersion": "3",
			"didError": false,
			"error": null,
			"data": {}
		}
		"""

		let result = decoder.decode(Data(json.utf8), operation: operation)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.schema.unsupported")
	}

	@Test
	func 성공_응답에_오류가_있으면_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "2",
			"didError": false,
			"error": "unexpected",
			"data": {"simulators": []}
		}
		"""

		let result = makeDecoder().decode(
			Data(json.utf8),
			operation: operation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	private func makeDecoder() -> XcodeBuildMCPOutputDecoder {
		.init(supportedSchemaVersions: [
			operation: ["xcodebuildmcp.output.simulator-list": ["2"]]
		])
	}
}

private extension XcodeBuildMCPResult {
	var error: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
