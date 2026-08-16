//
//  XcodeBuildMCPUIAutomationOutputTests.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCP UI automation 구조화 응답 형식을 검증합니다.
@Suite
struct XcodeBuildMCPUIAutomationOutputTests {
	// runtime snapshot capture 응답이 필요한 식별 정보만 보존하는지 검증합니다.
	@Test
	func runtime_snapshot_capture_응답이_식별정보를_보존한다() {
		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data("""
			{
				"schema": "xcodebuildmcp.output.capture-result",
				"schemaVersion": "2",
				"didError": false,
				"error": null,
				"data": {
					"capture": {
						"type": "runtime-snapshot",
						"screenHash": "screen-hash",
						"seq": 4,
						"secret": "discarded"
					}
				}
			}
			""".utf8),
			operation: .snapshot
		)

		#expect(result.result == .passed)
		#expect(result.payload == .object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			])
		]))
	}
}
