//
//  Scenario.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 실행 전 검증을 마친 app별 QA 시나리오를 표현합니다.
package struct Scenario: Codable, Sendable, Equatable {
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
package struct ScenarioStep: Codable, Sendable, Equatable {
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
package enum ScenarioStepAction: String, Codable, CaseIterable, Sendable, Equatable {
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
package struct ScenarioSelector: Codable, Sendable, Equatable {
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
}

// assertion과 evidence가 완료된 step을 참조하는 값을 표현합니다.
package struct ScenarioStepReference: Codable, Sendable, Equatable {
	package let afterStepID: String
	package let parameters: ScenarioValue?

	// 참조 대상 step과 불투명한 scenario data로 값을 구성합니다.
	package init(afterStepID: String, parameters: ScenarioValue? = nil) {
		self.afterStepID = afterStepID
		self.parameters = parameters
	}
}

// scenario 안의 app별 matrix와 parameter JSON 값을 손실 없이 표현합니다.
package enum ScenarioValue: Codable, Sendable, Equatable {
	case object([String: Self])
	case array([Self])
	case string(String)
	case integer(Int64)
	case unsignedInteger(UInt64)
	case number(Decimal)
	case boolean(Bool)
	case null

	// JSON 단일 값의 실제 종류를 분류해 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()

		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .boolean(value)
		} else if let value = try? container.decode(Int64.self) {
			self = .integer(value)
		} else if let value = try? container.decode(UInt64.self) {
			self = .unsignedInteger(value)
		} else if let value = try? container.decode(Decimal.self) {
			self = .number(value)
		} else if let value = try? container.decode(String.self) {
			self = .string(value)
		} else if let value = try? container.decode([Self].self) {
			self = .array(value)
		} else {
			self = try .object(container.decode([String: Self].self))
		}
	}

	// JSON 값의 실제 종류에 맞춰 인코딩합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()

		switch self {
		case .object(let value):
			try container.encode(value)
		case .array(let value):
			try container.encode(value)
		case .string(let value):
			try container.encode(value)
		case .integer(let value):
			try container.encode(value)
		case .unsignedInteger(let value):
			try container.encode(value)
		case .number(let value):
			try container.encode(value)
		case .boolean(let value):
			try container.encode(value)
		case .null:
			try container.encodeNil()
		}
	}
}
