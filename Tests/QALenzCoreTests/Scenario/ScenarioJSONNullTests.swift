//
//  ScenarioJSONNullTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// 형식이 정해진 scenario JSON key의 null 처리 계약을 검증합니다.
@Suite
struct ScenarioJSONNullTests {
	// 명시적 null을 거부할 JSON key 문맥을 표현합니다.
	private enum NullKey: CaseIterable, Sendable {
		case schemaVersion
		case id
		case name
		case profile
		case matrix
		case steps
		case assertions
		case evidence
		case stepID
		case action
		case identifier
		case label
		case role
		case value
		case assertionStepID
		case evidenceStepID

		// 오류 반환에 사용할 JSON key path를 반환합니다.
		var keyPath: String {
			switch self {
			case .schemaVersion:
				"$.schemaVersion"
			case .id:
				"$.id"
			case .name:
				"$.name"
			case .profile:
				"$.profile"
			case .matrix:
				"$.matrix"
			case .steps:
				"$.steps"
			case .assertions:
				"$.assertions"
			case .evidence:
				"$.evidence"
			case .stepID:
				"$.steps[0].id"
			case .action:
				"$.steps[0].action"
			case .identifier:
				"$.steps[0].selector.identifier"
			case .label:
				"$.steps[0].selector.label"
			case .role:
				"$.steps[0].selector.role"
			case .value:
				"$.steps[0].selector.value"
			case .assertionStepID:
				"$.assertions[0].afterStepID"
			case .evidenceStepID:
				"$.evidence[0].afterStepID"
			}
		}
	}

	// 형식이 정해진 key의 명시적 null을 파일 문맥과 함께 거부하는지 검증합니다.
	@Test(arguments: NullKey.allCases)
	private func 형식이_정해진_key의_명시적_null을_거부한다(_ key: NullKey) throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/null-typed-key.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(nullTypedKeyJSON(for: key).utf8),
				at: scenarioURL
			)
		}

		#expect(errors.errors == [
			.init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: key.keyPath
			)
		])
	}

	// 누락한 parameter와 명시적 null parameter를 서로 다른 원본 값으로 보존하는지 검증합니다.
	@Test
	private func 누락과_명시적_null_parameter를_구분한다() throws {
		let document = try ScenarioJSONDecoder().decode(
			Data(
				"""
				{
					"schemaVersion": 1,
					"id": "null-parameter-distinction",
					"name": "Null parameter distinction",
					"profile": "default",
					"matrix": {},
					"steps": [
						{"id": "without-parameter", "action": "buildAndRun"},
						{"id": "with-parameter", "action": "buildAndRun", "parameters": null}
					],
					"assertions": [
						{"afterStepID": "without-parameter"},
						{"afterStepID": "with-parameter", "parameters": null}
					],
					"evidence": [
						{"afterStepID": "without-parameter"},
						{"afterStepID": "with-parameter", "parameters": null}
					]
				}
				""".utf8
			)
		)
		let steps = try #require(document.steps)
		let assertions = try #require(document.assertions)
		let evidence = try #require(document.evidence)

		#expect(steps[0].parameters == nil)
		#expect(steps[1].parameters == .null)
		#expect(assertions[0].parameters == nil)
		#expect(assertions[1].parameters == .null)
		#expect(evidence[0].parameters == nil)
		#expect(evidence[1].parameters == .null)
	}

	// 명시적 null을 넣은 key 외에는 기본 JSON 값을 반환합니다.
	private func value(
		for expectedKey: NullKey,
		when key: NullKey,
		default defaultValue: String
	) -> String {
		key == expectedKey ? "null" : defaultValue
	}

	// 형식이 정해진 모든 scenario key를 포함한 JSON 원문을 반환합니다.
	private func nullTypedKeyJSON(for key: NullKey) -> String {
		let schemaVersion = value(for: .schemaVersion, when: key, default: "1")
		let id = value(for: .id, when: key, default: "\"null-typed-key\"")
		let name = value(for: .name, when: key, default: "\"Null typed key\"")
		let profile = value(for: .profile, when: key, default: "\"default\"")
		let matrix = value(for: .matrix, when: key, default: "{}")
		let stepID = value(for: .stepID, when: key, default: "\"launch\"")
		let action = value(for: .action, when: key, default: "\"buildAndRun\"")
		let identifier = value(for: .identifier, when: key, default: "\"launch-button\"")
		let label = value(for: .label, when: key, default: "\"Launch\"")
		let role = value(for: .role, when: key, default: "\"button\"")
		let selectorValue = value(for: .value, when: key, default: "\"ready\"")
		let step = """
		[{"id": \(stepID), "action": \(action), "selector": {
			"identifier": \(identifier), "label": \(label), "role": \(role), "value": \(selectorValue)
		}}]
		"""
		let steps = value(for: .steps, when: key, default: step)
		let assertionStepID = value(
			for: .assertionStepID,
			when: key,
			default: "\"assertion-step\""
		)
		let evidenceStepID = value(
			for: .evidenceStepID,
			when: key,
			default: "\"evidence-step\""
		)
		let assertions = value(
			for: .assertions,
			when: key,
			default: "[{\"afterStepID\": \(assertionStepID)}]"
		)
		let evidence = value(
			for: .evidence,
			when: key,
			default: "[{\"afterStepID\": \(evidenceStepID)}]"
		)

		return """
		{
			"schemaVersion": \(schemaVersion),
			"id": \(id),
			"name": \(name),
			"profile": \(profile),
			"matrix": \(matrix),
			"steps": \(steps),
			"assertions": \(assertions),
			"evidence": \(evidence)
		}
		"""
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
