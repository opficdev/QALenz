//
//  ScenarioSchemaTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// QALenz scenario JSON Schema와 Swift 계약의 일치 여부를 검증합니다.
@Suite
struct ScenarioSchemaTests {
	// JSON Schema의 최상위 key와 action tag가 Swift 모델과 일치하는지 검증합니다.
	@Test
	func JSON_Schema가_Scenario_모델과_action_tag에_일치한다() throws {
		let schema = try schemaObject()
		let requiredKeyNames = try #require(schema["required"] as? [String])
		let properties = try #require(schema["properties"] as? [String: [String: Any]])
		let steps = try #require(properties["steps"])
		let items = try #require(steps["items"] as? [String: Any])
		let stepProperties = try #require(items["properties"] as? [String: [String: Any]])
		let selector = try #require(stepProperties["selector"])
		let selectorProperties = try #require(selector["properties"] as? [String: [String: Any]])
		let actionVariants = try #require(items["oneOf"] as? [[String: Any]])
		let actionTags = try actionVariants.map { variant in
			let properties = try #require(variant["properties"] as? [String: [String: Any]])
			let action = try #require(properties["action"])

			return try #require(action["const"] as? String)
		}

		#expect(schema["type"] as? String == "object")
		#expect(requiredKeyNames == ScenarioDocument.requiredKeyNames)
		#expect(Set(properties.keys) == Set(ScenarioDocument.keyNames))
		#expect(selector["additionalProperties"] as? Bool == false)
		#expect(Set(selectorProperties.keys) == Set(ScenarioSelector.keyNames))
		#expect(actionTags == ScenarioStepAction.allCases.map(\.rawValue))
	}

	// module bundle의 scenario JSON Schema를 dictionary로 해석합니다.
	private func schemaObject() throws -> [String: Any] {
		let resourceURL = try #require(ScenarioSchema.resourceURL)
		let data = try Data(contentsOf: resourceURL)

		return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
	}
}
