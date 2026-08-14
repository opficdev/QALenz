//
//  Scenario.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 실행 전 검증을 마친 app별 QA 시나리오를 표현합니다.
package struct Scenario: Sendable, Equatable {
	package static let supportedSchemaVersion = 1

	package let schemaVersion: Int
	package let id: String
	package let name: String
	package let profile: String
	package let matrix: ScenarioValue
	package let steps: [ScenarioStep]
	package let assertions: [ScenarioStepReference]
	package let evidence: [ScenarioStepReference]

	// 검증을 마친 scenario data로 값을 구성합니다.
	package init(
		schemaVersion: Int,
		id: String,
		name: String,
		profile: String,
		matrix: ScenarioValue,
		steps: [ScenarioStep],
		assertions: [ScenarioStepReference],
		evidence: [ScenarioStepReference]
	) {
		self.schemaVersion = schemaVersion
		self.id = id
		self.name = name
		self.profile = profile
		self.matrix = matrix
		self.steps = steps
		self.assertions = assertions
		self.evidence = evidence
	}
}

// scenario 배열 순서로 실행할 하나의 동작을 표현합니다.
package struct ScenarioStep: Sendable, Equatable {
	package let id: String
	package let action: ScenarioStepAction
	package let selector: ScenarioSelector?
	package let parameters: ScenarioValue?

	// 식별자, action tag, app별 selector와 parameter로 step을 구성합니다.
	package init(
		id: String,
		action: ScenarioStepAction,
		selector: ScenarioSelector? = nil,
		parameters: ScenarioValue? = nil
	) {
		self.id = id
		self.action = action
		self.selector = selector
		self.parameters = parameters
	}
}

// 지원하는 scenario action tag를 정의합니다.
package enum ScenarioStepAction: String, CaseIterable, Sendable, Equatable {
	case buildAndRun
	case waitForUI
	case tap
	case longPress
	case swipe
	case typeText
	case screenshot
	case recordVideo

	// element selector가 필요한 action인지 반환합니다.
	package var requiresSelector: Bool {
		switch self {
		case .waitForUI, .tap, .longPress, .typeText:
			true
		case .buildAndRun, .swipe, .screenshot, .recordVideo:
			false
		}
	}
}

// app별 UI 요소를 scenario data로 한정해 표현합니다.
package struct ScenarioSelector: Sendable, Equatable {
	package let identifier: String?
	package let label: String?
	package let role: String?
	package let value: String?

	// 선택 가능한 app별 요소 정보를 구성합니다.
	package init(
		identifier: String? = nil,
		label: String? = nil,
		role: String? = nil,
		value: String? = nil
	) {
		self.identifier = identifier
		self.label = label
		self.role = role
		self.value = value
	}

	// 의미 있는 요소 식별 정보가 하나도 없는지 반환합니다.
	package var isEmpty: Bool {
		[identifier, label, role, value].allSatisfy {
			$0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
		}
	}

	// 빈 문자열 또는 공백만 제공한 selector key 이름을 반환합니다.
	package var emptyValueKeyNames: [String] {
		[
			("identifier", identifier),
			("label", label),
			("role", role),
			("value", value)
		].compactMap { pair in
			guard let value = pair.1 else { return nil }
			guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

			return pair.0
		}
	}
}

// assertion과 evidence가 완료된 step을 참조하는 값을 표현합니다.
package struct ScenarioStepReference: Sendable, Equatable {
	package let afterStepID: String
	package let parameters: ScenarioValue?

	// 참조 대상 step과 불투명한 scenario data로 값을 구성합니다.
	package init(afterStepID: String, parameters: ScenarioValue? = nil) {
		self.afterStepID = afterStepID
		self.parameters = parameters
	}
}

// scenario 안의 app별 matrix와 parameter JSON 값을 손실 없이 표현합니다.
package enum ScenarioValue: Sendable, Equatable {
	case object([String: Self])
	case array([Self])
	case string(String)
	case number(String)
	case boolean(Bool)
	case null
}
