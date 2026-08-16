//
//  ScenarioDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioDecoder의 JSON 해석과 시나리오 검증 계약을 검증합니다.
@Suite
struct ScenarioDecoderTests {
	// 지원하는 모든 action을 포함한 scenario가 JSON 왕복 변환 후에도 유지되는지 검증합니다.
	@Test
	func 모든_action을_포함한_scenario를_JSON_왕복_변환한다() throws {
		let scenarioURL = try fixtureURL(named: "valid")
		let decoder = ScenarioDecoder()
		let scenario = try #require(decoder.decode(at: scenarioURL).first)
		let data = try ScenarioJSONEncoder().encode(scenario)
		let decoded = try #require(
			decoder.decode(data, at: URL(fileURLWithPath: "/tmp/round-trip.json")).first
		)

		#expect(decoded == scenario)
		#expect(
			scenario.steps.map(\.action) == [
				.buildAndRun,
				.waitForUI,
				.snapshotUI,
				.tap,
				.longPress,
				.scroll,
				.typeText,
				.screenshot,
				.recordVideo
			]
		)
	}

	// selector와 matrix의 앱별 값이 변형되지 않은 scenario data로 유지되는지 검증합니다.
	@Test
	func 앱별_selector와_matrix_값을_불투명_scenario_data로_보존한다() throws {
		let scenarioURL = try fixtureURL(named: "valid")
		let scenario = try #require(ScenarioDecoder().decode(at: scenarioURL).first)
		let tapStep = try #require(scenario.steps.first { $0.id == "tap-profile" })
		let selector = try #require(tapStep.selector)

		#expect(selector.identifier == "profile-button")
		#expect(selector.label == "Profile")
		#expect(selector.role == "button")
		#expect(scenario.matrix == .object([
			"devices": .array([.string("iPhone 17 Pro")])
		]))
	}

	// schema에 없는 selector key가 파일 문맥과 함께 거부되는지 검증합니다.
	@Test
	func 미지정_selector_key를_파일_문맥으로_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/unknown-selector-key.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "unknown-selector-key",
					  "name": "Unknown selector key",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "tap-profile", "action": "tap", "selector": {"identifier": "profile-button", "identifer": "typo"}}],
					  "assertions": [],
					  "evidence": [],
					  "testDataRequirements": []
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
				keyPath: "$.steps[0].selector.identifer"
			)
		])
	}

	// 명시적 null selector가 파일 문맥과 함께 거부되는지 검증합니다.
	@Test
	func 명시적_null_selector를_파일_문맥으로_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/null-selector.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "null-selector",
					  "name": "Null selector",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "capture", "action": "screenshot", "selector": null}],
					  "assertions": [],
					  "evidence": [],
					  "testDataRequirements": []
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
				keyPath: "$.steps[0].selector"
			)
		])
	}

	// step과 step 참조의 명시적 null parameter가 JSON 왕복 변환 후에도 유지되는지 검증합니다.
	@Test
	func 명시적_null_parameter를_보존한다() throws {
		let decoder = ScenarioDecoder()
		let scenario = try #require(
			decoder.decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "null-parameters",
					  "name": "Null parameters",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "launch", "action": "buildAndRun", "parameters": null}],
					  "assertions": [{"afterStepID": "launch", "parameters": null}],
					  "evidence": [{"afterStepID": "launch", "parameters": null}],
					  "testDataRequirements": []
					}
					""".utf8
				),
				at: URL(fileURLWithPath: "/tmp/null-parameters.json")
			).first
		)

		#expect(scenario.steps.first?.parameters == .null)
		#expect(scenario.assertions.first?.parameters == .null)
		#expect(scenario.evidence.first?.parameters == .null)

		let encoded = try ScenarioJSONEncoder().encode(scenario)
		let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		let steps = try #require(object["steps"] as? [[String: Any]])
		let assertions = try #require(object["assertions"] as? [[String: Any]])
		let evidence = try #require(object["evidence"] as? [[String: Any]])

		#expect(steps.first?["parameters"] is NSNull)
		#expect(assertions.first?["parameters"] is NSNull)
		#expect(evidence.first?["parameters"] is NSNull)
	}

	// 큰 지수의 JSON 숫자가 원문과 숫자 종류를 유지한 채 왕복 변환되는지 검증합니다.
	@Test
	func 큰_지수_숫자_원문을_보존한다() throws {
		let decoder = ScenarioDecoder()
		let scenario = try #require(
			decoder.decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "large-numbers",
					  "name": "Large numbers",
					  "profile": "default",
					  "matrix": {"large": 1e200, "small": 1e-200},
					  "steps": [{"id": "launch", "action": "buildAndRun", "parameters": {"large": 1e200}}],
					  "assertions": [{"afterStepID": "launch", "parameters": 1e-200}],
					  "evidence": [{"afterStepID": "launch", "parameters": [1e200, 1e-200]}],
					  "testDataRequirements": []
					}
					""".utf8
				),
				at: URL(fileURLWithPath: "/tmp/large-numbers.json")
			).first
		)

		#expect(scenario.matrix == .object([
			"large": .number("1e200"),
			"small": .number("1e-200")
		]))
		#expect(scenario.steps.first?.parameters == .object(["large": .number("1e200")]))
		#expect(scenario.assertions.first?.parameters == .number("1e-200"))
		#expect(scenario.evidence.first?.parameters == .array([
			.number("1e200"),
			.number("1e-200")
		]))

		let encoded = try ScenarioJSONEncoder().encode(scenario)
		let encodedJSON = try #require(String(data: encoded, encoding: .utf8))
		let decoded = try #require(
			decoder.decode(encoded, at: URL(fileURLWithPath: "/tmp/large-numbers-round-trip.json")).first
		)

		#expect(encodedJSON.contains("1e200"))
		#expect(encodedJSON.contains("1e-200"))
		#expect(!encodedJSON.contains("\"1e200\""))
		#expect(!encodedJSON.contains("\"1e-200\""))
		#expect(decoded == scenario)
	}

	// 정수 값을 나타내는 지수 표기 schemaVersion을 기존 계약대로 해석하는지 검증합니다.
	@Test
	func 정수_지수_표기의_schemaVersion을_해석한다() throws {
		let scenario = try #require(
			ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1e0,
					  "id": "exponent-schema-version",
					  "name": "Exponent schema version",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "launch", "action": "buildAndRun"}],
					  "assertions": [],
					  "evidence": [],
					  "testDataRequirements": []
					}
					""".utf8
				),
				at: URL(fileURLWithPath: "/tmp/exponent-schema-version.json")
			).first
		)

		#expect(scenario.schemaVersion == 1)
	}

	// 구문이 잘못된 scenario JSON이 파일 문맥과 함께 거부되는지 검증합니다.
	@Test
	func 구문이_잘못된_JSON을_파일_문맥으로_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/invalid-scenario.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(Data("{".utf8), at: scenarioURL)
		}

		#expect(errors.errors == [
			.init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$"
			)
		])
	}

	// 읽을 수 없는 scenario 파일이 파일 문맥과 함께 거부되는지 검증합니다.
	@Test
	func 읽을_수_없는_파일을_파일_문맥으로_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(UUID().uuidString)
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(at: scenarioURL)
		}

		#expect(errors.errors == [
			.init(
				code: .fileUnreadable,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$"
			)
		])
	}

	// fixture 이름에 해당하는 Scenario JSON URL을 반환합니다.
	private func fixtureURL(named name: String) throws -> URL {
		try #require(
			Bundle.module.url(
				forResource: name,
				withExtension: "json",
				subdirectory: "Fixtures/Scenario"
			)
		)
	}

	// decoder가 반환한 여러 scenario 검증 오류를 추출합니다.
	private func requireValidationErrors(
		from operation: () throws -> [Scenario]
	) throws -> ScenarioValidationErrors {
		try #require(throws: ScenarioValidationErrors.self) {
			try operation()
		}
	}

}
