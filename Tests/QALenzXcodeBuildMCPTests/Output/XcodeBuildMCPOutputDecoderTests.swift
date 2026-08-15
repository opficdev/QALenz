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
	private let discoverProjectsOperation = XcodeBuildMCPOperation.discoverProjects
	private let discoverSchemesOperation = XcodeBuildMCPOperation.discoverSchemes
	private let discoverSimulatorsOperation = XcodeBuildMCPOperation.discoverSimulators

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

	// UI 도구 실패가 허용한 오류 코드와 마지막 snapshot만 보존하는지 검증합니다.
	@Test
	func UI_도구_실패가_구조화_오류_코드와_snapshot을_보존한다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.capture-result",
			"schemaVersion": "2",
			"didError": true,
			"error": "secret-token-value",
			"data": {
				"capture": {"type": "runtime-snapshot", "screenHash": "screen-hash", "seq": 4},
				"uiError": {"code": "WAIT_TIMEOUT", "message": "secret-message"}
			}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: .wait
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
		#expect(result.payload == .object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			]),
			"uiError": .object(["code": .string("WAIT_TIMEOUT")])
		]))
		#expect(!String(describing: result).contains("secret-message"))
	}

	// capture가 없는 UI 도구 실패도 구조화 오류 코드를 보존하는지 검증합니다.
	@Test
	func capture가_없는_UI_도구_실패가_구조화_오류_코드를_보존한다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.capture-result",
			"schemaVersion": "2",
			"didError": true,
			"error": "secret-token-value",
			"data": {"uiError": {"code": "SNAPSHOT_CAPTURE_FAILED"}}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: .snapshot
		)

		#expect(result.payload == .object([
			"uiError": .object(["code": .string("SNAPSHOT_CAPTURE_FAILED")])
		]))
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

	// project 후보 path 필드의 형식이 계약과 다르면 거부되는지 검증합니다.
	@Test
	func project_후보_path_필드의_형식이_계약과_다르면_거부한다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.project-list",
			"schemaVersion": "2",
			"didError": false,
			"error": null,
			"data": {"projects": [{"path": true}], "workspaces": []}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: discoverProjectsOperation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	// scheme 항목의 형식이 계약과 다르면 거부되는지 검증합니다.
	@Test
	func scheme_항목의_형식이_계약과_다르면_거부한다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.scheme-list",
			"schemaVersion": "2",
			"didError": false,
			"error": null,
			"data": {"schemes": [1]}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: discoverSchemesOperation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
	}

	// project 목록 응답의 지원하지 않는 schemaVersion이 거부되는지 검증합니다.
	@Test
	func project_목록_응답의_지원하지_않는_schemaVersion이_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.project-list",
			"schemaVersion": "1",
			"didError": false,
			"error": null,
			"data": {"projects": [], "workspaces": []}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: discoverProjectsOperation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.schema.unsupported")
	}

	// scheme 목록 응답의 지원하지 않는 schemaVersion이 거부되는지 검증합니다.
	@Test
	func scheme_목록_응답의_지원하지_않는_schemaVersion이_거부된다() throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.scheme-list",
			"schemaVersion": "1",
			"didError": false,
			"error": null,
			"data": {"schemes": []}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: discoverSchemesOperation
		)
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.schema.unsupported")
	}

	// simulator payload 필드의 형식이 계약과 다르면 거부되는지 검증합니다.
	@Test(arguments: [
		#"{"name":true,"simulatorId":"fixture-id","state":"Booted","isAvailable":true,"runtime":"iOS 26.0"}"#,
		#"{"name":"Fixture Phone","simulatorId":1,"state":"Booted","isAvailable":true,"runtime":"iOS 26.0"}"#,
		#"{"name":"Fixture Phone","simulatorId":"fixture-id","state":false,"isAvailable":true,"runtime":"iOS 26.0"}"#,
		#"{"name":"Fixture Phone","simulatorId":"fixture-id","state":"Booted","isAvailable":"false","runtime":"iOS 26.0"}"#,
		#"{"name":"Fixture Phone","simulatorId":"fixture-id","state":"Booted","isAvailable":true,"runtime":26}"#
	])
	func simulator_payload_필드의_형식이_계약과_다르면_거부한다(_ simulator: String) throws {
		let json = """
		{
			"schema": "xcodebuildmcp.output.simulator-list",
			"schemaVersion": "2",
			"didError": false,
			"error": null,
			"data": {"simulators": [\(simulator)]}
		}
		"""

		let result = XcodeBuildMCPV2.outputDecoder.decode(
			Data(json.utf8),
			operation: discoverSimulatorsOperation
		)
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
