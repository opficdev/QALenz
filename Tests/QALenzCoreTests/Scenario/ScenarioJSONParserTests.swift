//
//  ScenarioJSONParserTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioJSONParser의 숫자 문법 검증을 확인합니다.
@Suite
struct ScenarioJSONParserTests {
	// 지수부에 중복 부호나 누락한 숫자가 있으면 거부하는지 검증합니다.
	@Test(arguments: ["1e+-2", "1e+", "1e--1"])
	func 잘못된_지수부를_거부한다(_ literal: String) {
		#expect(throws: ScenarioJSONSyntaxError.self) {
			var parser = ScenarioJSONParser(data: Data(literal.utf8))

			_ = try parser.parse()
		}
	}

	// 잘못된 숫자 문자열을 포함한 Scenario를 JSON으로 출력하지 않는지 검증합니다.
	@Test
	func 잘못된_숫자_문자열을_출력하지_않는다() {
		let scenario = Scenario(
			schemaVersion: 1,
			id: "invalid-number",
			name: "Invalid number",
			profile: "default",
			matrix: .object(["value": .number("1e+-2")]),
			steps: [.init(id: "launch", action: .buildAndRun)],
			assertions: [],
			evidence: []
		)

		#expect(throws: ScenarioJSONEncodingError.self) {
			try ScenarioJSONEncoder().encode(scenario)
		}
	}
}
