//
//  ScenarioStepValidator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// assertion과 evidence의 JSON 문맥 및 오류 코드를 구분합니다.
enum ScenarioStepReferenceKind {
	case assertion
	case evidence

	// 참조 배열의 JSON key path를 반환합니다.
	var keyPath: String {
		switch self {
		case .assertion:
			"$.assertions"
		case .evidence:
			"$.evidence"
		}
	}

	// 참조 실패에 사용할 오류 코드를 반환합니다.
	var errorCode: ScenarioValidationError.Code {
		switch self {
		case .assertion:
			.assertionStepUnresolved
		case .evidence:
			.evidenceStepUnresolved
		}
	}
}

// 한 scenario 안의 step과 step 참조를 검증합니다.
struct ScenarioStepValidator {
	// step의 빈 값, id 중복, action tag, selector 조건을 검증합니다.
	func validate(
		_ steps: [ScenarioStepDocument]?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) -> Set<String> {
		guard let steps else {
			appendMissingKey(filePath: filePath, keyPath: "$.steps", errors: &errors)
			return []
		}
		guard !steps.isEmpty else {
			errors.append(.init(code: .stepsEmpty, filePath: filePath, keyPath: "$.steps"))
			return []
		}

		var stepIDs = Set<String>()

		for (index, step) in steps.enumerated() {
			validate(step, at: index, stepIDs: &stepIDs, filePath: filePath, errors: &errors)
		}

		return stepIDs
	}

	// assertion 또는 evidence가 같은 scenario의 완료 step을 참조하는지 검증합니다.
	func validateReferences(
		_ references: [ScenarioStepReferenceDocument]?,
		stepIDs: Set<String>,
		filePath: String,
		kind: ScenarioStepReferenceKind,
		errors: inout [ScenarioValidationError]
	) {
		guard let references else {
			appendMissingKey(filePath: filePath, keyPath: kind.keyPath, errors: &errors)
			return
		}

		for (index, reference) in references.enumerated() {
			let keyPath = "\(kind.keyPath)[\(index)].afterStepID"

			guard let stepID = reference.afterStepID else {
				appendMissingKey(filePath: filePath, keyPath: keyPath, errors: &errors)
				continue
			}
			guard stepIDs.contains(stepID) else {
				errors.append(.init(code: kind.errorCode, filePath: filePath, keyPath: keyPath))
				continue
			}
		}
	}

	// 한 step의 id, action, selector 조건을 검증합니다.
	private func validate(
		_ step: ScenarioStepDocument,
		at index: Int,
		stepIDs: inout Set<String>,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		let keyPath = "$.steps[\(index)]"

		guard !isEmpty(step) else {
			errors.append(.init(code: .stepEmpty, filePath: filePath, keyPath: keyPath))
			return
		}

		validateID(step.id, keyPath: keyPath, filePath: filePath, stepIDs: &stepIDs, errors: &errors)
		let action = validateAction(step.action, keyPath: keyPath, filePath: filePath, errors: &errors)
		validateProvidedSelector(step.selector, keyPath: keyPath, filePath: filePath, errors: &errors)

		if let action {
			validateRequiredSelector(step.selector, for: action, keyPath: keyPath, filePath: filePath, errors: &errors)
		}
	}

	// step id의 누락, 형식, 중복 여부를 검증합니다.
	private func validateID(
		_ id: String?,
		keyPath: String,
		filePath: String,
		stepIDs: inout Set<String>,
		errors: inout [ScenarioValidationError]
	) {
		guard let id else {
			appendMissingKey(filePath: filePath, keyPath: "\(keyPath).id", errors: &errors)
			return
		}
		guard ScenarioIdentifierValidator.isValid(id) else {
			errors.append(.init(code: .idInvalid, filePath: filePath, keyPath: "\(keyPath).id"))
			return
		}
		guard stepIDs.insert(id).inserted else {
			errors.append(.init(code: .stepIDDuplicate, filePath: filePath, keyPath: "\(keyPath).id"))
			return
		}
	}

	// raw action tag를 지원 action으로 변환하며 오류를 수집합니다.
	private func validateAction(
		_ actionName: String?,
		keyPath: String,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) -> ScenarioStepAction? {
		guard let actionName else {
			appendMissingKey(filePath: filePath, keyPath: "\(keyPath).action", errors: &errors)
			return nil
		}
		guard let action = ScenarioStepAction(rawValue: actionName) else {
			errors.append(.init(
				code: .stepActionUnsupported,
				filePath: filePath,
				keyPath: "\(keyPath).action"
			))
			return nil
		}

		return action
	}

	// 제공된 selector의 빈 값과 빈 object를 검증합니다.
	private func validateProvidedSelector(
		_ selector: ScenarioSelector?,
		keyPath: String,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let selector else { return }

		let emptyValueKeyNames = selector.emptyValueKeyNames

		guard emptyValueKeyNames.isEmpty else {
			for keyName in emptyValueKeyNames {
				errors.append(.init(
					code: .stepSelectorEmpty,
					filePath: filePath,
					keyPath: "\(keyPath).selector.\(keyName)"
				))
			}
			return
		}
		guard !selector.isEmpty else {
			errors.append(.init(
				code: .stepSelectorEmpty,
				filePath: filePath,
				keyPath: "\(keyPath).selector"
			))
			return
		}
	}

	// action에 필요한 selector가 제공됐는지 검증합니다.
	private func validateRequiredSelector(
		_ selector: ScenarioSelector?,
		for action: ScenarioStepAction,
		keyPath: String,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard selector == nil, action.requiresSelector else { return }

		errors.append(.init(
			code: .stepSelectorMissing,
			filePath: filePath,
			keyPath: "\(keyPath).selector"
		))
	}

	// step이 id, action, selector, parameter를 전혀 포함하지 않는지 반환합니다.
	private func isEmpty(_ step: ScenarioStepDocument) -> Bool {
		step.id == nil
			&& step.action == nil
			&& step.selector == nil
			&& step.parameters == nil
	}

	// 필수 key 누락 오류를 정해진 문맥으로 추가합니다.
	private func appendMissingKey(
		filePath: String,
		keyPath: String,
		errors: inout [ScenarioValidationError]
	) {
		errors.append(.init(code: .keyMissing, filePath: filePath, keyPath: keyPath))
	}
}
