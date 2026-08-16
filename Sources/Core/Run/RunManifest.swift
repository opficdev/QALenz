//
//  RunManifest.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// 완료된 run의 최소 재현 metadata와 결과를 표현합니다.
package struct RunManifest: Codable, Sendable, Equatable {
	package let id: UUID
	package let createdAt: Date
	package let qalenzVersion: String
	package let scenario: RunManifestScenario
	package let result: RunResult
	package let targets: [RunTargetResult]

	// 실행 식별자와 정규화된 결과로 manifest를 구성합니다.
	package init(
		id: UUID,
		createdAt: Date,
		qalenzVersion: String = QALenzCoreVersion.current,
		scenario: RunManifestScenario,
		result: RunResult,
		targets: [RunTargetResult]
	) throws {
		guard result != .passed || (!targets.isEmpty && targets.allSatisfy { $0.result == .passed }) else {
			throw RunManifestValidationError.manifestPassedWithNonPassingTarget
		}

		self.id = id
		self.createdAt = createdAt
		self.qalenzVersion = qalenzVersion
		self.scenario = scenario
		self.result = result
		self.targets = targets
	}

	// JSON 값을 결과 정합성을 검증한 manifest로 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			id: container.decode(UUID.self, forKey: .id),
			createdAt: container.decode(Date.self, forKey: .createdAt),
			qalenzVersion: container.decode(String.self, forKey: .qalenzVersion),
			scenario: container.decode(RunManifestScenario.self, forKey: .scenario),
			result: container.decode(RunResult.self, forKey: .result),
			targets: container.decode([RunTargetResult].self, forKey: .targets)
		)
	}

	// manifest 값을 JSON에 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(id, forKey: .id)
		try container.encode(createdAt, forKey: .createdAt)
		try container.encode(qalenzVersion, forKey: .qalenzVersion)
		try container.encode(scenario, forKey: .scenario)
		try container.encode(result, forKey: .result)
		try container.encode(targets, forKey: .targets)
	}

	// JSON key를 정의합니다.
	private enum CodingKeys: String, CodingKey {
		case id
		case createdAt
		case qalenzVersion
		case scenario
		case result
		case targets
	}
}

// manifest에 보존할 scenario의 식별 정보만 표현합니다.
package struct RunManifestScenario: Codable, Sendable, Equatable {
	package let id: String
	package let profile: String

	// scenario 식별자와 profile로 구성합니다.
	package init(id: String, profile: String) {
		self.id = id
		self.profile = profile
	}
}

// 하나의 target에서 완료한 step 결과와 증거 참조를 표현합니다.
package struct RunTargetResult: Codable, Sendable, Equatable {
	package let target: Target
	package let result: RunResult
	package let stepResults: [RunStepResult]
	package let evidence: [EvidenceReference]
	package let startedAt: Date?
	package let endedAt: Date?

	// target 결과, step 결과, 증거 참조로 구성합니다.
	package init(
		target: Target,
		result: RunResult,
		stepResults: [RunStepResult],
		evidence: [EvidenceReference],
		startedAt: Date? = nil,
		endedAt: Date? = nil
	) throws {
		guard result != .passed || (!stepResults.isEmpty && stepResults.allSatisfy { $0.result == .passed }) else {
			throw RunManifestValidationError.targetPassedWithNonPassingStep
		}
		guard Self.isValidTimeRange(startedAt: startedAt, endedAt: endedAt) else {
			throw RunManifestValidationError.targetTimeRangeInvalid
		}
		guard stepResults.allSatisfy({ $0.isWithin(startedAt: startedAt, endedAt: endedAt) }) else {
			throw RunManifestValidationError.stepTimeRangeInvalid
		}

		self.target = target
		self.result = result
		self.stepResults = stepResults
		self.evidence = evidence
		self.startedAt = startedAt
		self.endedAt = endedAt
	}

	// JSON 값을 결과 정합성을 검증한 target 결과로 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			target: container.decode(Target.self, forKey: .target),
			result: container.decode(RunResult.self, forKey: .result),
			stepResults: container.decode([RunStepResult].self, forKey: .stepResults),
			evidence: container.decode([EvidenceReference].self, forKey: .evidence),
			startedAt: container.decodeIfPresent(Date.self, forKey: .startedAt),
			endedAt: container.decodeIfPresent(Date.self, forKey: .endedAt)
		)
	}

	// target 결과를 JSON에 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(target, forKey: .target)
		try container.encode(result, forKey: .result)
		try container.encode(stepResults, forKey: .stepResults)
		try container.encode(evidence, forKey: .evidence)
		try container.encodeIfPresent(startedAt, forKey: .startedAt)
		try container.encodeIfPresent(endedAt, forKey: .endedAt)
	}

	// 시작과 종료 시각이 함께 있고 순서가 올바른지 반환합니다.
	private static func isValidTimeRange(startedAt: Date?, endedAt: Date?) -> Bool {
		switch (startedAt, endedAt) {
		case (nil, nil): true
		case let (.some(startedAt), .some(endedAt)): startedAt <= endedAt
		default: false
		}
	}

	// JSON key를 정의합니다.
	private enum CodingKeys: String, CodingKey {
		case target
		case result
		case stepResults
		case evidence
		case startedAt
		case endedAt
	}
}

// 상위 통과 결과가 하위 결과를 가리는 오류를 정의합니다.
package enum RunManifestValidationError: Error, Sendable, Equatable {
	case manifestPassedWithNonPassingTarget
	case targetPassedWithNonPassingStep
	case targetTimeRangeInvalid
	case stepTimeRangeInvalid
}

// 하나의 scenario step의 정규화된 결과를 표현합니다.
package struct RunStepResult: Codable, Sendable, Equatable {
	package let stepID: String
	package let result: RunResult
	package let selector: ScenarioSelector?
	package let attempts: Int?
	package let uiSnapshot: UIAutomationSnapshot?
	package let startedAt: Date?
	package let endedAt: Date?

	// step 식별자와 결과로 구성합니다.
	package init(
		stepID: String,
		result: RunResult,
		selector: ScenarioSelector? = nil,
		attempts: Int? = nil,
		uiSnapshot: UIAutomationSnapshot? = nil,
		startedAt: Date? = nil,
		endedAt: Date? = nil
	) {
		self.stepID = stepID
		self.result = result
		self.selector = selector
		self.attempts = attempts
		self.uiSnapshot = uiSnapshot
		self.startedAt = startedAt
		self.endedAt = endedAt
	}

	// step 시각이 target 시각 범위에 포함되는지 반환합니다.
	fileprivate func isWithin(startedAt targetStartedAt: Date?, endedAt targetEndedAt: Date?) -> Bool {
		switch (startedAt, endedAt, targetStartedAt, targetEndedAt) {
		case (nil, nil, nil, nil): true
		case let (.some(startedAt), .some(endedAt), .some(targetStartedAt), .some(targetEndedAt)):
			targetStartedAt <= startedAt && startedAt <= endedAt && endedAt <= targetEndedAt
		default: false
		}
	}
}

// manifest JSON의 날짜 형식과 key 순서를 고정합니다.
package struct RunManifestCodec: Sendable {
	// 기본 codec을 구성합니다.
	package init() {}

	// manifest를 UTC ISO 8601 날짜 문자열과 정렬된 key로 인코딩합니다.
	package func encode(_ manifest: RunManifest) throws -> Data {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		return try encoder.encode(manifest)
	}

	// UTC ISO 8601 날짜 문자열을 manifest로 복원합니다.
	package func decode(_ data: Data) throws -> RunManifest {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		return try decoder.decode(RunManifest.self, from: data)
	}
}
