//
//  XcodeBuildMCPOutputDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPOutputDecoder의 envelope 정규화를 검증합니다.
@Suite
struct XcodeBuildMCPOutputDecoderTests {
	private let operation = XcodeBuildMCPOperation(rawValue: "fixture.list")

	// 정상 envelope가 허용된 payload만 포함한 결과로 변환되는지 검증합니다.
	@Test
	func 지원하는_성공_응답이_통과_결과로_변환된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.fixture",
			"schemaVersion": "1",
			"didError": false,
			"error": null,
			"data": {"items": [], "secretToken": "secret-token-value"},
			"nextSteps": ["xcodebuildmcp simulator list"]
		}
		"""

		let decoder = makeDecoder()
		let result = decoder.decode(Data(json.utf8), operation: operation)
		let envelope = try decoder.decodeEnvelope(Data(json.utf8))

		#expect(result.result == .passed)
		#expect(result.payload == .object(["items": .array([])]))
		#expect(envelope.nextSteps == ["xcodebuildmcp simulator list"])
	}

	// didError 응답이 원본 오류를 노출하지 않는지 검증합니다.
	@Test
	func 도구_실패가_원본_오류_내용_없이_정규화된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.fixture",
			"schemaVersion": "1",
			"didError": true,
			"error": "secret-token-value",
			"data": {"items": []}
		}
		"""

		let result = makeDecoder().decode(Data(json.utf8), operation: operation)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	// 잘못된 JSON이 구조화된 출력 오류로 변환되는지 검증합니다.
	@Test
	func 잘못된_JSON이_구조화된_출력_오류로_변환된다() throws {
		let result = makeDecoder().decode(
			Data("{malformed".utf8),
			operation: operation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	// 지원하지 않는 schemaVersion이 거부되는지 검증합니다.
	@Test
	func 지원하지_않는_응답_형식_버전이_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.fixture",
			"schemaVersion": "99",
			"didError": false,
			"error": null,
			"data": {"items": []}
		}
		"""

		let result = makeDecoder().decode(Data(json.utf8), operation: operation)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.schema.unsupported")
	}

	// 필수 payload가 없는 성공 응답이 거부되는지 검증합니다.
	@Test
	func 필수_payload가_없는_성공_응답이_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.fixture",
			"schemaVersion": "1",
			"didError": false,
			"error": null,
			"data": {}
		}
		"""

		let result = makeDecoder().decode(Data(json.utf8), operation: operation)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	// fixture operation의 output 정의를 주입한 decoder를 구성합니다.
	private func makeDecoder() -> XcodeBuildMCPOutputDecoder {
		.init(outputDefinitions: [
			operation: [
				"xcodebuildmcp.output.fixture": .init(
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
		])
	}
}

// 오류 결과에서 RunError를 꺼냅니다.
private extension XcodeBuildMCPResult {
	// errored 결과의 RunError를 반환합니다.
	var error: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
