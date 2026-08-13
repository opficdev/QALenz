//
//  DoctorDiagnostic.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// Doctor 검사 항목의 상태와 안내를 전달합니다.
package struct DoctorDiagnostic: Codable, Sendable, Equatable {
	package let id: Identifier
	package let requirement: Requirement
	package let status: Status
	package let message: String
	package let recommendation: String?

	// 검사 항목의 구성 값으로 초기화합니다.
	package init(
		id: Identifier,
		requirement: Requirement,
		status: Status,
		message: String,
		recommendation: String? = nil
	) {
		self.id = id
		self.requirement = requirement
		self.status = status
		self.message = message
		self.recommendation = recommendation
	}
}

// Doctor 검사 항목에 사용하는 중첩 타입을 정의합니다.
extension DoctorDiagnostic {
	// 검사 항목을 식별하는 문자열 값을 전달합니다.
	package struct Identifier: RawRepresentable, Codable, Sendable, Equatable {
		package let rawValue: String

		// 원시 문자열 식별자로 초기화합니다.
		package init(rawValue: String) {
			self.rawValue = rawValue
		}

		// 디코더에서 검사 항목 식별자를 복원합니다.
		package init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()

			rawValue = try container.decode(String.self)
		}

		// 인코더에 검사 항목 식별자를 기록합니다.
		package func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()

			try container.encode(rawValue)
		}
	}

	// 검사 항목의 필수 수준을 나타냅니다.
	package enum Requirement: String, Codable, Sendable, Equatable {
		case required
		case recommended
	}

	// 검사 항목의 확인 상태를 나타냅니다.
	package enum Status: String, Codable, Sendable, Equatable {
		case available
		case missing
		case unsupported
	}
}
