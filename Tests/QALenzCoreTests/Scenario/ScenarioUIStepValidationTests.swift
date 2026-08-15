//
//  ScenarioUIStepValidationTests.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation
import Testing
@testable import QALenzCore

// UI step의 v1 selector 계약을 검증합니다.
@Suite
struct ScenarioUIStepValidationTests {
	// v1에서 selector 없는 scroll을 실행 전에 거부하는지 검증합니다.
	@Test
	func selector_없는_scroll을_거부한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/scroll-selector.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "scroll-selector",
					  "name": "Scroll selector",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "scroll-list", "action": "scroll"}],
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
				code: .stepSelectorMissing,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$.steps[0].selector"
			)
		])
	}

	// v1에서 이전 swipe action 별칭을 구조화 오류로 거부하는지 검증합니다.
	@Test
	func 이전_swipe_action을_거부한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/swipe-action.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "swipe-action",
					  "name": "Swipe action",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "swipe-list", "action": "swipe", "selector": {"identifier": "todo-list"}}],
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
				code: .stepActionUnsupported,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$.steps[0].action"
			)
		])
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
