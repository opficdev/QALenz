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
		let data = try JSONEncoder().encode(scenario)
		let decoded = try #require(
			decoder.decode(data, at: URL(fileURLWithPath: "/tmp/round-trip.json")).first
		)

		#expect(decoded == scenario)
		#expect(
			scenario.steps.map(\.action) == [
				.buildAndRun,
				.waitForUI,
				.tap,
				.longPress,
				.swipe,
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
			"devices": .array([.string("iPhone 17 Pro")]),
			"language": .string("ko-KR")
		]))
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
