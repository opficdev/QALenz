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
	) {
		self.id = id
		self.createdAt = createdAt
		self.qalenzVersion = qalenzVersion
		self.scenario = scenario
		self.result = result
		self.targets = targets
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

	// target 결과, step 결과, 증거 참조로 구성합니다.
	package init(
		target: Target,
		result: RunResult,
		stepResults: [RunStepResult],
		evidence: [EvidenceReference]
	) {
		self.target = target
		self.result = result
		self.stepResults = stepResults
		self.evidence = evidence
	}
}

// 하나의 scenario step의 정규화된 결과를 표현합니다.
package struct RunStepResult: Codable, Sendable, Equatable {
	package let stepID: String
	package let result: RunResult

	// step 식별자와 결과로 구성합니다.
	package init(stepID: String, result: RunResult) {
		self.stepID = stepID
		self.result = result
	}
}

// manifest JSON의 날짜 정밀도와 key 순서를 고정합니다.
package struct RunManifestCodec: Sendable {
	// 기본 codec을 구성합니다.
	package init() {}

	// manifest를 고정 JSON 형식으로 인코딩합니다.
	package func encode(_ manifest: RunManifest) throws -> Data {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		return try encoder.encode(manifest)
	}

	// 고정 JSON 형식의 manifest를 복원합니다.
	package func decode(_ data: Data) throws -> RunManifest {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		return try decoder.decode(RunManifest.self, from: data)
	}
}
