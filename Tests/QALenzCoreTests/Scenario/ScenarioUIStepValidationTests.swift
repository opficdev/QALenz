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
	// v1에서 selector 없는 swipe를 실행 전에 거부하는지 검증합니다.
	@Test
	func selector_없는_swipe를_거부한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/swipe-selector.json")
		let errors = try requireValidationErrors {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "swipe-selector",
					  "name": "Swipe selector",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "swipe-list", "action": "swipe"}],
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

	// decoder가 반환한 여러 scenario 검증 오류를 추출합니다.
	private func requireValidationErrors(
		from operation: () throws -> [Scenario]
	) throws -> ScenarioValidationErrors {
		try #require(throws: ScenarioValidationErrors.self) {
			try operation()
		}
	}
}
