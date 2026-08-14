//
//  ScenarioJSONParserTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioJSONParser의 숫자 문법 검증을 확인합니다.
@Suite
struct ScenarioJSONParserTests {
	// 최대 중첩 깊이 경계를 구성할 JSON container 종류를 표현합니다.
	private enum NestedJSONKind: CaseIterable {
		case object
		case array
		case mixed
	}

	// object와 array의 최대 중첩 깊이까지는 해석하는지 검증합니다.
	@Test(arguments: NestedJSONKind.allCases)
	private func 최대_중첩_깊이까지_JSON을_해석한다(_ kind: NestedJSONKind) throws {
		var parser = ScenarioJSONParser(data: Data(nestedJSON(kind: kind, depth: 128).utf8))

		_ = try parser.parse()
	}

	// object와 array의 최대 중첩 깊이를 넘으면 거부하는지 검증합니다.
	@Test(arguments: NestedJSONKind.allCases)
	private func 최대_중첩_깊이를_넘는_JSON을_거부한다(_ kind: NestedJSONKind) throws {
		let error = try #require(throws: ScenarioJSONSyntaxError.self) {
			var parser = ScenarioJSONParser(data: Data(nestedJSON(kind: kind, depth: 129).utf8))

			_ = try parser.parse()
		}

		#expect(error == .nestingLimitExceeded)
	}

	// 중첩 깊이 초과를 root JSON path의 scenario 구문 오류로 정규화하는지 검증합니다.
	@Test
	func 중첩_깊이_초과를_root_JSON_key_path와_함께_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/nesting-limit.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
						"matrix": \(nestedJSON(kind: .mixed, depth: 128)),
						"schemaVersion": 1,
						"id": "nesting-limit",
						"name": "Nesting limit",
						"profile": "default",
						"steps": [{"id": "launch", "action": "buildAndRun"}],
						"assertions": [],
						"evidence": []
					}
					""".utf8
				),
				at: scenarioURL
			)
		}

		#expect(errors.errors == [
			.init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$"
			)
		])
	}

	// 중복 JSON object member를 정확한 JSON path와 함께 거부하는지 검증합니다.
	@Test(arguments: [
		("{\"id\": \"first\", \"id\": \"second\"}", "$.id"),
		("{\"parameters\": {\"invalid.key\": 1, \"invalid.key\": 2}}", "$.parameters[\"invalid.key\"]")
	])
	func 중복_JSON_object_member를_거부한다(_ json: String, _ keyPath: String) throws {
		let error = try #require(throws: ScenarioJSONSyntaxError.self) {
			var parser = ScenarioJSONParser(data: Data(json.utf8))

			_ = try parser.parse()
		}

		#expect(error == .duplicateMember(keyPath: keyPath))
	}

	// 중복 object member를 JSON key path와 함께 scenario 오류로 정규화하는지 검증합니다.
	@Test
	func 중복_object_member를_JSON_key_path와_함께_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/duplicate-member.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
						"schemaVersion": 1,
						"id": "duplicate-member",
						"name": "Duplicate member",
						"profile": "default",
						"matrix": {},
						"steps": [
							{"id": "launch", "id": "duplicate", "action": "buildAndRun"}
						],
						"assertions": [],
						"evidence": []
					}
					""".utf8
				),
				at: scenarioURL
			)
		}

		#expect(errors.errors == [
			.init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$.steps[0].id"
			)
		])
	}

	// 지수부에 중복 부호나 누락한 숫자가 있으면 거부하는지 검증합니다.
	@Test(arguments: ["1e+-2", "1e+", "1e--1"])
	func 잘못된_지수부를_거부한다(_ literal: String) {
		#expect(throws: ScenarioJSONSyntaxError.self) {
			var parser = ScenarioJSONParser(data: Data(literal.utf8))

			_ = try parser.parse()
		}
	}

	// 잘못된 숫자 문자열을 포함한 Scenario를 JSON으로 출력하지 않는지 검증합니다.
	@Test
	func 잘못된_숫자_문자열을_출력하지_않는다() {
		let scenario = Scenario(
			schemaVersion: 1,
			id: "invalid-number",
			name: "Invalid number",
			profile: "default",
			matrix: .object(["value": .number("1e+-2")]),
			steps: [.init(id: "launch", action: .buildAndRun)],
			assertions: [],
			evidence: []
		)

		#expect(throws: ScenarioJSONEncodingError.self) {
			try ScenarioJSONEncoder().encode(scenario)
		}
	}

	// decoder가 반환한 여러 scenario 검증 오류를 추출합니다.
	private func requireValidationErrors(
		from operation: () throws -> [Scenario]
	) throws -> ScenarioValidationErrors {
		try #require(throws: ScenarioValidationErrors.self) {
			try operation()
		}
	}

	// 요청한 깊이만큼 JSON object와 array를 중첩한 원문을 반환합니다.
	private func nestedJSON(kind: NestedJSONKind, depth: Int) -> String {
		var json = "null"

		for index in 0..<depth {
			switch kind {
			case .object:
				json = "{\"value\":\(json)}"
			case .array:
				json = "[\(json)]"
			case .mixed:
				json = index.isMultiple(of: 2) ? "{\"value\":\(json)}" : "[\(json)]"
			}
		}

		return json
	}
}
