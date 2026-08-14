//
//  ScenarioStepValidatorTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioStepValidator의 step 단위 의미 검증을 검증합니다.
@Suite
struct ScenarioStepValidatorTests {
	// 빈 step, 중복 id, 미지원 action, 빈 selector를 함께 반환하는지 검증합니다.
	@Test
	func step_의미_오류를_JSON_key_path와_함께_반환한다() throws {
		let steps = try decodeSteps(
			"""
			[
			  {},
			  {"id": "tap-profile", "action": "tap", "selector": {"identifier": "profile-button"}},
			  {"id": "tap-profile", "action": "unsupported"},
			  {"id": "wait-home", "action": "waitForUI", "selector": {}}
			]
			"""
		)
		var errors = [ScenarioValidationError]()
		let stepIDs = ScenarioStepValidator().validate(
			steps,
			filePath: "/tmp/scenario.json",
			errors: &errors
		)

		#expect(stepIDs == ["tap-profile", "wait-home"])
		#expect(errors.map(\.code.rawValue) == [
			"scenario.step.empty",
			"scenario.step.id.duplicate",
			"scenario.step.action.unsupported",
			"scenario.step.selector.empty"
		])
		#expect(errors.map(\.keyPath) == [
			"$.steps[0]",
			"$.steps[2].id",
			"$.steps[2].action",
			"$.steps[3].selector"
		])
	}

	// 제공된 selector의 빈 값이 action 종류와 무관하게 해당 key path로 반환되는지 검증합니다.
	@Test
	func selector의_빈_제공_값을_key_path로_반환한다() throws {
		let steps = try decodeSteps(
			"""
			[
			  {"id": "tap-profile", "action": "tap", "selector": {"identifier": "", "label": "Profile"}},
			  {"id": "capture", "action": "screenshot", "selector": {"value": ""}}
			]
			"""
		)
		var errors = [ScenarioValidationError]()
		let stepIDs = ScenarioStepValidator().validate(
			steps,
			filePath: "/tmp/scenario.json",
			errors: &errors
		)

		#expect(stepIDs == ["tap-profile", "capture"])
		#expect(errors.map(\.code.rawValue) == [
			"scenario.step.selector.empty",
			"scenario.step.selector.empty"
		])
		#expect(errors.map(\.keyPath) == [
			"$.steps[0].selector.identifier",
			"$.steps[1].selector.value"
		])
	}

	// action 오류가 있어도 제공된 selector의 빈 값을 함께 반환하는지 검증합니다.
	@Test
	func action_오류와_selector의_빈_제공_값을_함께_반환한다() throws {
		let steps = try decodeSteps(
			"""
			[
			  {"id": "missing-action", "selector": {"identifier": ""}},
			  {"id": "unsupported-action", "action": "unsupported", "selector": {"value": ""}},
			  {"id": "missing-action-object", "selector": {}},
			  {"id": "unsupported-action-object", "action": "unsupported", "selector": {}}
			]
			"""
		)
		var errors = [ScenarioValidationError]()
		let stepIDs = ScenarioStepValidator().validate(
			steps,
			filePath: "/tmp/scenario.json",
			errors: &errors
		)

		#expect(stepIDs == [
			"missing-action",
			"unsupported-action",
			"missing-action-object",
			"unsupported-action-object"
		])
		#expect(errors.map(\.code.rawValue) == [
			"scenario.key.missing",
			"scenario.step.selector.empty",
			"scenario.step.action.unsupported",
			"scenario.step.selector.empty",
			"scenario.key.missing",
			"scenario.step.selector.empty",
			"scenario.step.action.unsupported",
			"scenario.step.selector.empty"
		])
		#expect(errors.map(\.keyPath) == [
			"$.steps[0].action",
			"$.steps[0].selector.identifier",
			"$.steps[1].action",
			"$.steps[1].selector.value",
			"$.steps[2].action",
			"$.steps[2].selector",
			"$.steps[3].action",
			"$.steps[3].selector"
		])
	}

	// step 배열을 포함한 최소 scenario JSON을 전용 decoder로 해석합니다.
	private func decodeSteps(_ steps: String) throws -> [ScenarioStepDocument] {
		let document = try ScenarioJSONDecoder().decode(
			Data(
				"""
				{
				  "schemaVersion": 1,
				  "id": "steps",
				  "name": "Steps",
				  "profile": "default",
				  "matrix": {},
				  "steps": \(steps),
				  "assertions": [],
				  "evidence": [],
				  "testDataRequirements": []
				}
				""".utf8
			)
		)

		return try #require(document.steps)
	}
}
