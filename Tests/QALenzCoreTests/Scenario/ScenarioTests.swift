//
//  ScenarioTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// Scenario 도메인 값의 JSON 계약을 검증합니다.
@Suite
struct ScenarioTests {
	// Scenario와 불투명 app별 data가 전용 JSON codec 왕복 변환 후에도 유지되는지 검증합니다.
	@Test
	func Scenario와_앱별_data를_JSON_왕복_변환한다() throws {
		let scenario = Scenario(
			schemaVersion: 1,
			id: "todo-completion",
			name: "Todo completion",
			profile: "default",
			matrix: .object([
				"device": .string("iPhone 17 Pro")
			]),
			steps: [
				.init(
					id: "tap-complete",
					action: .tap,
					selector: .init(identifier: "todo-complete"),
					parameters: .object([
						"retryCount": .number("1")
					])
				)
			],
			assertions: [
				.init(afterStepID: "tap-complete")
			],
			evidence: [
				.init(afterStepID: "tap-complete", parameters: .boolean(true))
			]
		)
		let data = try ScenarioJSONEncoder().encode(scenario)
		let decoded = try #require(
			ScenarioDecoder().decode(
				data,
				at: URL(fileURLWithPath: "/tmp/scenario-codec.json")
			).first
		)

		#expect(decoded == scenario)
	}
}
