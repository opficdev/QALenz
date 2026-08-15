//
//  ScenarioValidator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 해석한 scenario 문서와 원본 파일 위치를 함께 전달합니다.
package struct ScenarioDocumentLocation: Sendable {
	package let document: ScenarioDocument
	package let url: URL

	// 원본 문서와 파일 위치로 값을 구성합니다.
	package init(document: ScenarioDocument, url: URL) {
		self.document = document
		self.url = url
	}
}

// scenario 검증의 정규화된 값과 수집 오류를 함께 전달합니다.
package struct ScenarioValidationResult: Sendable {
	package let scenarios: [Scenario]
	package let errors: [ScenarioValidationError]

	// 검증한 scenario와 오류 목록으로 값을 구성합니다.
	package init(scenarios: [Scenario], errors: [ScenarioValidationError]) {
		self.scenarios = scenarios
		self.errors = errors
	}
}

// scenario 문서의 구조와 참조 무결성을 검증합니다.
package struct ScenarioValidator: Sendable {
	// 기본 검증기로 값을 구성합니다.
	package init() {}

	// 입력 순서를 보존하며 여러 scenario 문서의 오류를 함께 수집합니다.
	package func validate(
		_ locations: [ScenarioDocumentLocation]
	) -> ScenarioValidationResult {
		var errors = [ScenarioValidationError]()
		var scenarios = [Scenario]()
		var scenarioLocations = [String: [URL]]()
		var orderedScenarioIDs = [String]()

		for location in locations {
			let start = errors.count
			validate(location.document, at: location.url, errors: &errors)

			if let id = location.document.id, isValidIdentifier(id) {
				if scenarioLocations[id] == nil {
					orderedScenarioIDs.append(id)
				}
				scenarioLocations[id, default: []].append(location.url)
			}

			guard start == errors.count else { continue }
			guard let scenario = makeScenario(from: location.document) else { continue }

			scenarios.append(scenario)
		}

		for id in orderedScenarioIDs {
			guard let urls = scenarioLocations[id] else { continue }
			guard 1 < urls.count else { continue }

			for url in urls {
				errors.append(.init(
					code: .idDuplicate,
					filePath: url.standardizedFileURL.path,
					keyPath: "$.id"
				))
			}
		}

		return .init(scenarios: scenarios, errors: errors)
	}

	// 한 scenario 문서의 필수 값, step, 참조를 순서대로 검증합니다.
	private func validate(
		_ document: ScenarioDocument,
		at url: URL,
		errors: inout [ScenarioValidationError]
	) {
		let filePath = url.standardizedFileURL.path
		validateSchemaVersion(document.schemaVersion, filePath: filePath, errors: &errors)
		validateScenarioID(document.id, filePath: filePath, errors: &errors)
		validateName(document.name, filePath: filePath, errors: &errors)
		validateProfile(document.profile, filePath: filePath, errors: &errors)
		validateMatrix(document.matrix, filePath: filePath, errors: &errors)
		let stepValidator = ScenarioStepValidator()
		let stepIDs = stepValidator.validate(document.steps, filePath: filePath, errors: &errors)
		stepValidator.validateReferences(
			document.assertions,
			stepIDs: stepIDs,
			filePath: filePath,
			kind: .assertion,
			errors: &errors
		)
		stepValidator.validateReferences(
			document.evidence,
			stepIDs: stepIDs,
			filePath: filePath,
			kind: .evidence,
			errors: &errors
		)
		TestDataRequirementValidator().validate(
			document.testDataRequirements,
			filePath: filePath,
			errors: &errors
		)
	}

	// 지원하는 schemaVersion인지 검증합니다.
	private func validateSchemaVersion(
		_ schemaVersion: Int?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let schemaVersion else {
			appendMissingKey(filePath: filePath, keyPath: "$.schemaVersion", errors: &errors)
			return
		}
		guard schemaVersion == Scenario.supportedSchemaVersion else {
			errors.append(.init(
				code: .schemaUnsupported,
				filePath: filePath,
				keyPath: "$.schemaVersion"
			))
			return
		}
	}

	// 최상위 scenario id의 필수 여부와 형식을 검증합니다.
	private func validateScenarioID(
		_ id: String?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let id else {
			appendMissingKey(filePath: filePath, keyPath: "$.id", errors: &errors)
			return
		}
		guard isValidIdentifier(id) else {
			errors.append(.init(code: .idInvalid, filePath: filePath, keyPath: "$.id"))
			return
		}
	}

	// scenario 이름이 비어 있지 않은지 검증합니다.
	private func validateName(
		_ name: String?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let name else {
			appendMissingKey(filePath: filePath, keyPath: "$.name", errors: &errors)
			return
		}
		guard !isBlank(name) else {
			errors.append(.init(code: .nameEmpty, filePath: filePath, keyPath: "$.name"))
			return
		}
	}

	// profile이 비어 있지 않은 app별 scenario data인지 검증합니다.
	private func validateProfile(
		_ profile: String?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let profile else {
			appendMissingKey(filePath: filePath, keyPath: "$.profile", errors: &errors)
			return
		}
		guard !isBlank(profile) else {
			errors.append(.init(code: .profileEmpty, filePath: filePath, keyPath: "$.profile"))
			return
		}
	}

	// matrix가 project별 값을 담는 JSON object인지 검증합니다.
	private func validateMatrix(
		_ matrix: ScenarioValue?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let matrix else {
			appendMissingKey(filePath: filePath, keyPath: "$.matrix", errors: &errors)
			return
		}
		guard case .object = matrix else {
			errors.append(.init(code: .matrixInvalid, filePath: filePath, keyPath: "$.matrix"))
			return
		}
	}

	// 이미 의미 검증을 통과한 문서를 실행 계층이 받을 Scenario로 변환합니다.
	private func makeScenario(from document: ScenarioDocument) -> Scenario? {
		guard
			let schemaVersion = document.schemaVersion,
			let id = document.id,
			let name = document.name,
			let profile = document.profile,
			let matrix = document.matrix,
			let steps = document.steps,
			let assertions = document.assertions,
			let evidence = document.evidence,
			let testDataRequirements = document.testDataRequirements
		else { return nil }

		let scenarioSteps = steps.compactMap { step -> ScenarioStep? in
			guard let id = step.id, let actionName = step.action else { return nil }
			guard let action = ScenarioStepAction(rawValue: actionName) else { return nil }

			return .init(
				id: id,
				action: action,
				selector: step.selector,
				parameters: step.parameters
			)
		}
		let scenarioAssertions = assertions.compactMap { reference -> ScenarioStepReference? in
			guard let afterStepID = reference.afterStepID else { return nil }

			return .init(afterStepID: afterStepID, parameters: reference.parameters)
		}
		let scenarioEvidence = evidence.compactMap { reference -> ScenarioStepReference? in
			guard let afterStepID = reference.afterStepID else { return nil }

			return .init(afterStepID: afterStepID, parameters: reference.parameters)
		}
		let scenarioTestDataRequirements = makeTestDataRequirements(
			from: testDataRequirements
		)

		guard steps.count == scenarioSteps.count else { return nil }
		guard assertions.count == scenarioAssertions.count else { return nil }
		guard evidence.count == scenarioEvidence.count else { return nil }
		guard testDataRequirements.count == scenarioTestDataRequirements.count else { return nil }

		return .init(
			schemaVersion: schemaVersion,
			id: id,
			name: name,
			profile: profile,
			matrix: matrix,
			steps: scenarioSteps,
			assertions: scenarioAssertions,
			evidence: scenarioEvidence,
			testDataRequirements: scenarioTestDataRequirements
		)
	}

	// 검증한 requirement 문서를 실행 계층 값으로 변환합니다.
	private func makeTestDataRequirements(
		from requirements: [TestDataRequirementDocument]
	) -> [TestDataRequirement] {
		requirements.compactMap { requirement -> TestDataRequirement? in
			guard let operationName = requirement.operation,
				let operation = TestDataOperation(rawValue: operationName),
				let resource = requirement.resource else {
				return nil
			}

			return .init(operation: operation, resource: resource)
		}
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

	// 소문자와 숫자, 하이픈으로 구성한 scenario 식별자인지 반환합니다.
	private func isValidIdentifier(_ id: String) -> Bool {
		ScenarioIdentifierValidator.isValid(id)
	}

	// 공백과 줄바꿈만 포함한 문자열인지 반환합니다.
	private func isBlank(_ value: String) -> Bool {
		value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}
