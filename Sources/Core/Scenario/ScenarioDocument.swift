//
//  ScenarioDocument.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// scenario JSON을 검증 전에 보존하는 원본 구조를 표현합니다.
package struct ScenarioDocument: Sendable {
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

	// Scenario JSON codec이 해석한 원본 값으로 문서를 구성합니다.
	package init(
		schemaVersion: Int?,
		id: String?,
		name: String?,
		profile: String?,
		matrix: ScenarioValue?,
		steps: [ScenarioStepDocument]?,
		assertions: [ScenarioStepReferenceDocument]?,
		evidence: [ScenarioStepReferenceDocument]?
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

// 검증 전 step의 raw action tag와 선택 payload를 표현합니다.
package struct ScenarioStepDocument: Sendable {
	package let id: String?
	package let action: String?
	package let selector: ScenarioSelector?
	package let parameters: ScenarioValue?

	// Scenario JSON codec이 해석한 step 원본 값으로 문서를 구성합니다.
	package init(
		id: String?,
		action: String?,
		selector: ScenarioSelector?,
		parameters: ScenarioValue?
	) {
		self.id = id
		self.action = action
		self.selector = selector
		self.parameters = parameters
	}

}

// 검증 전 assertion과 evidence의 step 참조를 표현합니다.
package struct ScenarioStepReferenceDocument: Sendable {
	package let afterStepID: String?
	package let parameters: ScenarioValue?

	// Scenario JSON codec이 해석한 step 참조 원본 값으로 문서를 구성합니다.
	package init(afterStepID: String?, parameters: ScenarioValue?) {
		self.afterStepID = afterStepID
		self.parameters = parameters
	}

}
