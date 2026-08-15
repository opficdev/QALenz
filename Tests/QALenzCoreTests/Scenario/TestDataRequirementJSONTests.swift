//
//  TestDataRequirementJSONTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// test data requirement JSON 계약의 미지정 key 처리를 검증합니다.
@Suite
struct TestDataRequirementJSONTests {
	// schema에 없는 test data requirement key가 파일 문맥과 함께 거부되는지 검증합니다.
	@Test
	func 미지정_testDataRequirement_key를_파일_문맥으로_반환한다() throws {
		let scenarioURL = URL(fileURLWithPath: "/tmp/unknown-test-data-requirement-key.json")
		let errors = try #require(throws: ScenarioValidationErrors.self) {
			try ScenarioDecoder().decode(
				Data(
					"""
					{
					  "schemaVersion": 1,
					  "id": "unknown-test-data-requirement-key",
					  "name": "Unknown test data requirement key",
					  "profile": "default",
					  "matrix": {},
					  "steps": [{"id": "launch", "action": "buildAndRun"}],
					  "assertions": [],
					  "evidence": [],
					  "testDataRequirements": [{"operation": "create", "resource": "todo", "resorce": "typo"}]
					}
					""".utf8
				),
				at: scenarioURL
			)
		}

		#expect(errors.errors == [.init(
			code: .jsonInvalid,
			filePath: scenarioURL.standardizedFileURL.path,
			keyPath: "$.testDataRequirements[0].resorce"
		)])
	}
}
