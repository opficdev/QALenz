//
//  ScenarioCatalog.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// project에 등록한 scenario와 파일별 validation 상태를 표현합니다.
package struct ScenarioCatalog: Codable, Sendable, Equatable {
	package let entries: [ScenarioCatalogEntry]

	// 정렬한 scenario catalog 항목으로 구성합니다.
	package init(entries: [ScenarioCatalogEntry]) {
		self.entries = entries
	}

	// catalog에 오류 항목이 있으면 verification 실패 결과를 반환합니다.
	package var result: RunResult {
		entries.allSatisfy { $0.status == .valid } ? .passed : .failed
	}
}

// scenario 파일 하나의 요약과 validation 상태를 표현합니다.
package struct ScenarioCatalogEntry: Codable, Sendable, Equatable {
	package let id: String?
	package let name: String?
	package let profile: String?
	package let filePath: String
	package let status: Status
	package let errors: [ScenarioValidationError]

	// 원본 scenario 필드와 파일별 validation 결과로 구성합니다.
	package init(
		id: String?,
		name: String?,
		profile: String?,
		filePath: String,
		status: Status,
		errors: [ScenarioValidationError]
	) {
		self.id = id
		self.name = name
		self.profile = profile
		self.filePath = filePath
		self.status = status
		self.errors = errors
	}
}

// scenario 파일의 validation 상태를 나타냅니다.
extension ScenarioCatalogEntry {
	package enum Status: String, Codable, Sendable, Equatable {
		case valid
		case invalid
	}
}
