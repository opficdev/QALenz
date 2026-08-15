//
//  TestDataRequirementValidator.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// scenario test data 요구사항의 필수 여부와 의미를 검증합니다.
struct TestDataRequirementValidator {
	// requirements의 누락, operation, resource를 검증합니다.
	func validate(
		_ requirements: [TestDataRequirementDocument]?,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		guard let requirements else {
			errors.append(.init(
				code: .keyMissing,
				filePath: filePath,
				keyPath: "$.testDataRequirements"
			))
			return
		}

		for (index, requirement) in requirements.enumerated() {
			validate(requirement, at: index, filePath: filePath, errors: &errors)
		}
	}

	// 한 requirement의 operation과 resource를 검증합니다.
	private func validate(
		_ requirement: TestDataRequirementDocument,
		at index: Int,
		filePath: String,
		errors: inout [ScenarioValidationError]
	) {
		let keyPath = "$.testDataRequirements[\(index)]"

		if let operation = requirement.operation {
			if TestDataOperation(rawValue: operation) == nil {
				errors.append(.init(
					code: .testDataRequirementOperationUnsupported,
					filePath: filePath,
					keyPath: "\(keyPath).operation"
				))
			}
		} else {
			appendMissingKey(filePath: filePath, keyPath: "\(keyPath).operation", errors: &errors)
		}

		if let resource = requirement.resource {
			if resource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				errors.append(.init(
					code: .testDataRequirementResourceEmpty,
					filePath: filePath,
					keyPath: "\(keyPath).resource"
				))
			}
		} else {
			appendMissingKey(filePath: filePath, keyPath: "\(keyPath).resource", errors: &errors)
		}
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
