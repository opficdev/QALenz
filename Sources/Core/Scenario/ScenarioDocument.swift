//
//  ScenarioDocument.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// JSONDecoder가 해석할 scenario 파일의 원본 구조를 표현합니다.
package struct ScenarioDocument: Decodable, Sendable {
	package static let requiredKeyNames = [
		"schemaVersion",
		"id",
		"name",
		"profile",
		"matrix",
		"steps",
		"assertions",
		"evidence"
	]

	package static let keyNames = requiredKeyNames

	package let schemaVersion: Int?
	package let id: String?
	package let name: String?
	package let profile: String?
	package let matrix: ScenarioValue?
	package let steps: [ScenarioStepDocument]?
	package let assertions: [ScenarioStepReferenceDocument]?
	package let evidence: [ScenarioStepReferenceDocument]?

	// 누락된 key를 의미 검증 단계에서 함께 수집하도록 선택 값으로 해석합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
		id = try container.decodeIfPresent(String.self, forKey: .id)
		name = try container.decodeIfPresent(String.self, forKey: .name)
		profile = try container.decodeIfPresent(String.self, forKey: .profile)
		matrix = try container.decodeIfPresent(ScenarioValue.self, forKey: .matrix)
		steps = try container.decodeIfPresent([ScenarioStepDocument].self, forKey: .steps)
		assertions = try container.decodeIfPresent(
			[ScenarioStepReferenceDocument].self,
			forKey: .assertions
		)
		evidence = try container.decodeIfPresent(
			[ScenarioStepReferenceDocument].self,
			forKey: .evidence
		)
	}

	// scenario JSON key를 decoding에 사용합니다.
	private enum CodingKeys: String, CodingKey {
		case schemaVersion
		case id
		case name
		case profile
		case matrix
		case steps
		case assertions
		case evidence
	}
}

// 검증 전 step의 raw action tag와 선택 payload를 표현합니다.
package struct ScenarioStepDocument: Decodable, Sendable {
	package let id: String?
	package let action: String?
	package let selector: ScenarioSelector?
	package let parameters: ScenarioValue?

	// 누락된 step key를 의미 검증 단계에서 수집하도록 선택 값으로 해석합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		id = try container.decodeIfPresent(String.self, forKey: .id)
		action = try container.decodeIfPresent(String.self, forKey: .action)
		selector = try container.decodeIfPresent(ScenarioSelector.self, forKey: .selector)
		parameters = try container.decodeIfPresent(ScenarioValue.self, forKey: .parameters)
	}

	// step JSON key를 decoding에 사용합니다.
	private enum CodingKeys: String, CodingKey {
		case id
		case action
		case selector
		case parameters
	}
}

// 검증 전 assertion과 evidence의 step 참조를 표현합니다.
package struct ScenarioStepReferenceDocument: Decodable, Sendable {
	package let afterStepID: String?
	package let parameters: ScenarioValue?

	// 누락된 참조 key를 의미 검증 단계에서 수집하도록 선택 값으로 해석합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		afterStepID = try container.decodeIfPresent(String.self, forKey: .afterStepID)
		parameters = try container.decodeIfPresent(ScenarioValue.self, forKey: .parameters)
	}

	// step 참조 JSON key를 decoding에 사용합니다.
	private enum CodingKeys: String, CodingKey {
		case afterStepID
		case parameters
	}
}
