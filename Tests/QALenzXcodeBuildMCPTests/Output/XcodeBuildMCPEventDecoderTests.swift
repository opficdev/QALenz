//
//  XcodeBuildMCPEventDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite
struct XcodeBuildMCPEventDecoderTests {
	private let operation = XcodeBuildMCPOperation(
		rawValue: "build.simulator"
	)

	@Test
	func normalizesJSONLinesEvents() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let jsonLines = """
		{"event":"build-result.invocation","operation":"BUILD"}
		{"event":"build-result.build-stage","message":"Compiling"}
		{"event":"build-result.build-summary","status":"SUCCEEDED"}

		"""

		let events = try decoder.decode(
			Data(jsonLines.utf8),
			operation: operation
		)

		#expect(events.map(\.kind) == [.started, .progress, .completed])
		#expect(events.map(\.message) == [nil, "Compiling", "SUCCEEDED"])
	}

	@Test
	func buffersSplitEventUntilNewlineArrives() throws {
		var decoder = XcodeBuildMCPEventDecoder()

		let first = try decoder.decode(
			Data(#"{"event":"build-result.build-stage","message":"Com"#.utf8),
			operation: operation
		)
		let second = try decoder.decode(
			Data("piling\"}\n".utf8),
			operation: operation
		)

		#expect(first.isEmpty)
		#expect(second.map(\.message) == ["Compiling"])
	}

	@Test
	func decodesFinalEventWithoutTrailingNewline() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let json = #"{"event":"build-result.build-summary","status":"FAILED"}"#

		let pending = try decoder.decode(
			Data(json.utf8),
			operation: operation
		)
		let final = try decoder.finish(operation: operation)

		#expect(pending.isEmpty)
		#expect(final.map(\.kind) == [.completed])
		#expect(final.map(\.message) == ["FAILED"])
	}

	@Test
	func rejectsMalformedEventWithoutCopyingRawLine() throws {
		var decoder = XcodeBuildMCPEventDecoder()

		do {
			_ = try decoder.decode(
				Data("secret-token-value\n".utf8),
				operation: operation
			)
			Issue.record("Expected malformed event error")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
			#expect(!String(describing: error).contains("secret-token-value"))
		}
	}
}
