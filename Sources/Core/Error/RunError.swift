//
//  RunError.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

// QA 실행 중 발생한 오류의 분류와 문맥을 전달합니다.
package struct RunError: Error, Codable, Sendable, Equatable {
	package let kind: Kind
	package let code: Code
	package let context: Context

	// 오류 분류, 코드, 문맥으로 초기화합니다.
	package init(
		kind: Kind,
		code: Code,
		context: Context = .init()
	) {
		self.kind = kind
		self.code = code
		self.context = context
	}
}

// 오류 구성에 필요한 중첩 타입을 정의합니다.
extension RunError {
	// 오류가 발생한 처리 영역을 나타냅니다.
	package enum Kind: String, Codable, Sendable, Equatable {
		case configuration
		case adapter
		case execution
		case evidence
		case verdict
		case report
	}

	// 오류 식별 코드를 문자열로 전달합니다.
	package struct Code: RawRepresentable, Codable, Sendable, Equatable {
		package let rawValue: String

		// 원시 문자열 코드로 초기화합니다.
		package init(rawValue: String) {
			self.rawValue = rawValue
		}

		// 디코더에서 오류 코드를 복원합니다.
		package init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()

			rawValue = try container.decode(String.self)
		}

		// 오류 코드를 인코더에 기록합니다.
		package func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()

			try container.encode(rawValue)
		}
	}

	// 오류가 발생한 명령과 대상 문맥을 전달합니다.
	package struct Context: Codable, Sendable, Equatable {
		package let command: String?
		package let target: String?
		package let step: String?
		package let assertion: String?

		// 선택 문맥 값으로 초기화합니다.
		package init(
			command: String? = nil,
			target: String? = nil,
			step: String? = nil,
			assertion: String? = nil
		) {
			self.command = command
			self.target = target
			self.step = step
			self.assertion = assertion
		}
	}
}
