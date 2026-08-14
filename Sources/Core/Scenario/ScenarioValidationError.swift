//
//  ScenarioValidationError.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// scenario 검증에서 발견한 한 건의 파일 및 JSON key path 오류를 표현합니다.
package struct ScenarioValidationError: Sendable, Equatable {
	package enum Code: String, Sendable, Equatable {
		case fileUnreadable = "scenario.file.unreadable"
		case jsonInvalid = "scenario.json.invalid"
		case keyMissing = "scenario.key.missing"
		case schemaUnsupported = "scenario.schema.unsupported"
		case idInvalid = "scenario.id.invalid"
		case idDuplicate = "scenario.id.duplicate"
		case nameEmpty = "scenario.name.empty"
		case profileEmpty = "scenario.profile.empty"
		case matrixInvalid = "scenario.matrix.invalid"
		case stepsEmpty = "scenario.steps.empty"
		case stepEmpty = "scenario.step.empty"
		case stepIDDuplicate = "scenario.step.id.duplicate"
		case stepActionUnsupported = "scenario.step.action.unsupported"
		case stepSelectorMissing = "scenario.step.selector.missing"
		case stepSelectorEmpty = "scenario.step.selector.empty"
		case assertionStepUnresolved = "scenario.assertion.step.unresolved"
		case evidenceStepUnresolved = "scenario.evidence.step.unresolved"
	}

	package let code: Code
	package let filePath: String
	package let keyPath: String

	// 오류 코드와 source 문맥으로 값을 구성합니다.
	package init(code: Code, filePath: String, keyPath: String) {
		self.code = code
		self.filePath = filePath
		self.keyPath = keyPath
	}
}

// 한 번의 scenario 검증에서 수집한 모든 오류를 함께 전달합니다.
package struct ScenarioValidationErrors: Error, Sendable, Equatable {
	package let errors: [ScenarioValidationError]

	// 정해진 순서의 검증 오류 목록으로 값을 구성합니다.
	package init(errors: [ScenarioValidationError]) {
		self.errors = errors
	}
}
