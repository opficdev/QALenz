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
	func normalizesSuccessfulEnvelope() throws {
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
	func normalizesToolFailureWithoutCopyingErrorText() throws {
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
	func rejectsMalformedJSON() throws {
		let result = makeDecoder().decode(
			Data("{malformed".utf8),
			operation: operation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	@Test
	func rejectsUnsupportedSchemaVersion() throws {
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
	func rejectsErrorTextOnSuccessfulEnvelope() throws {
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
			"xcodebuildmcp.output.simulator-list": ["2"]
		])
	}
}

private extension XcodeBuildMCPResult {
	var error: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
