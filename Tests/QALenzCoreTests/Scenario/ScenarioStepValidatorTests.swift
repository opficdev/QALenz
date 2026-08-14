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
		let steps = try JSONDecoder().decode(
			[ScenarioStepDocument].self,
			from: Data(
				"""
				[
				  {},
				  {"id": "tap-profile", "action": "tap", "selector": {"identifier": "profile-button"}},
				  {"id": "tap-profile", "action": "unsupported"},
				  {"id": "wait-home", "action": "waitForUI", "selector": {}}
				]
				""".utf8
			)
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
}
