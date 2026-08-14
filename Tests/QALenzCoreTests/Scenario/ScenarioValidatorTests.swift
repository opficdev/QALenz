//
//  ScenarioValidatorTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioValidator의 의미 검증 계약을 검증합니다.
@Suite
struct ScenarioValidatorTests {
	// 한 scenario의 여러 의미 오류가 파일 경로와 JSON key path를 포함해 함께 반환되는지 검증합니다.
	@Test
	func 여러_의미_오류를_파일_경로와_JSON_key_path로_함께_반환한다() throws {
		let scenarioURL = try fixtureURL(named: "invalid-validation")
		let result = try validateDocuments(at: [scenarioURL])

		#expect(result.errors.map(\.code.rawValue) == [
			"scenario.schema.unsupported",
			"scenario.id.invalid",
			"scenario.profile.empty",
			"scenario.matrix.invalid",
			"scenario.step.empty",
			"scenario.step.id.duplicate",
			"scenario.step.action.unsupported",
			"scenario.step.selector.empty",
			"scenario.assertion.step.unresolved",
			"scenario.evidence.step.unresolved"
		])
		#expect(result.errors.allSatisfy {
			$0.filePath == scenarioURL.standardizedFileURL.path
		})
		#expect(result.errors.map(\.keyPath) == [
			"$.schemaVersion",
			"$.id",
			"$.profile",
			"$.matrix",
			"$.steps[0]",
			"$.steps[2].id",
			"$.steps[2].action",
			"$.steps[3].selector",
			"$.assertions[0].afterStepID",
			"$.evidence[0].afterStepID"
		])
	}

	// 여러 scenario의 최상위 id 중복이 각각의 파일과 key path로 반환되는지 검증합니다.
	@Test
	func 여러_scenario의_중복_id를_각_파일_문맥으로_반환한다() throws {
		let document = try ScenarioJSONDecoder().decode(duplicateIDData())
		let firstURL = URL(fileURLWithPath: "/tmp/first-scenario.json")
		let secondURL = URL(fileURLWithPath: "/tmp/second-scenario.json")
		let result = ScenarioValidator().validate([
			.init(document: document, url: firstURL),
			.init(document: document, url: secondURL)
		])
		let duplicateErrors = result.errors.filter {
			$0.code.rawValue == "scenario.id.duplicate"
		}

		#expect(duplicateErrors.count == 2)
		#expect(Set(duplicateErrors.map(\.filePath)) == [
			firstURL.standardizedFileURL.path,
			secondURL.standardizedFileURL.path
		])
		#expect(duplicateErrors.allSatisfy { $0.keyPath == "$.id" })
	}

	// 다른 의미 오류가 있는 scenario도 유효한 id의 중복 오류를 함께 반환하는지 검증합니다.
	@Test
	func 다른_의미_오류가_있는_scenario의_중복_id도_반환한다() throws {
		let validDocument = try ScenarioJSONDecoder().decode(duplicateIDData())
		let invalidDocument = try ScenarioJSONDecoder().decode(duplicateIDData(profile: ""))
		let firstURL = URL(fileURLWithPath: "/tmp/first-scenario.json")
		let secondURL = URL(fileURLWithPath: "/tmp/second-scenario.json")
		let result = ScenarioValidator().validate([
			.init(document: validDocument, url: firstURL),
			.init(document: invalidDocument, url: secondURL)
		])

		#expect(result.errors.map(\.code.rawValue) == [
			"scenario.profile.empty",
			"scenario.id.duplicate",
			"scenario.id.duplicate"
		])
		#expect(result.errors.map(\.filePath) == [
			secondURL.standardizedFileURL.path,
			firstURL.standardizedFileURL.path,
			secondURL.standardizedFileURL.path
		])
		#expect(result.errors.map(\.keyPath) == ["$.profile", "$.id", "$.id"])
	}

	// test data 요구사항의 누락과 잘못된 값을 각 JSON key path로 반환하는지 검증합니다.
	@Test
	func testDataRequirements_계약_오류를_반환한다() throws {
		let document = try ScenarioJSONDecoder().decode(
			Data(
				"""
				{
				  "schemaVersion": 1,
				  "id": "test-data-requirements",
				  "name": "Test data requirements",
				  "profile": "default",
				  "matrix": {},
				  "steps": [{"id": "launch", "action": "buildAndRun"}],
				  "assertions": [],
				  "evidence": [],
				  "testDataRequirements": [
					{},
					{"operation": "reset", "resource": "todo"},
					{"operation": "delete", "resource": "   "}
				  ]
				}
				""".utf8
			)
		)
		let result = ScenarioValidator().validate([
			.init(document: document, url: URL(fileURLWithPath: "/tmp/test-data-requirements.json"))
		])

		#expect(result.errors.map(\.code) == [
			.keyMissing,
			.testDataRequirementOperationUnsupported,
			.testDataRequirementResourceEmpty
		])
		#expect(result.errors.map(\.keyPath) == [
			"$.testDataRequirements[0].operation",
			"$.testDataRequirements[1].operation",
			"$.testDataRequirements[2].resource"
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

	// fixture의 JSON을 raw scenario 문서와 파일 위치로 변환합니다.
	private func validateDocuments(at scenarioURLs: [URL]) throws -> ScenarioValidationResult {
		let locations = try scenarioURLs.map { scenarioURL in
			let data = try Data(contentsOf: scenarioURL)
			let document = try ScenarioJSONDecoder().decode(data)

			return ScenarioDocumentLocation(document: document, url: scenarioURL)
		}

		return ScenarioValidator().validate(locations)
	}

	// 중복 scenario id 검증에 사용할 최소 scenario 문서 JSON을 반환합니다.
	private func duplicateIDData(profile: String = "default") -> Data {
		Data(
			"""
			{
			  "schemaVersion": 1,
			  "id": "todo-completion",
			  "name": "Todo completion",
			  "profile": "\(profile)",
			  "matrix": {},
			  "steps": [{"id": "launch", "action": "buildAndRun"}],
			  "assertions": [],
			  "evidence": [],
			  "testDataRequirements": []
			}
			""".utf8
		)
	}
}
