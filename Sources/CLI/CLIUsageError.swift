//
//  CLIUsageError.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// 사용 오류의 결과와 안내 내용을 전달합니다.
package struct CLIUsageError: Codable, Sendable, Equatable {
	package let result: RunResult
	package let message: String
	package let usage: String

	// 오류 메시지와 사용법으로 초기화합니다.
	package init(message: String, usage: String) {
		result = .errored(
			.init(
				kind: .configuration,
				code: .init(rawValue: "cli.usage.invalid"),
				context: .init(command: "qalenz")
			)
		)
		self.message = message
		self.usage = usage
	}

	// 디코더에서 사용 오류를 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let result = try container.decode(RunResult.self, forKey: .result)

		guard case .errored = result else {
			throw DecodingError.dataCorruptedError(
				forKey: .result,
				in: container,
				debugDescription: "A CLI usage error requires an errored result."
			)
		}

		self.result = result
		message = try container.decode(String.self, forKey: .message)
		usage = try container.decode(String.self, forKey: .usage)
	}

	// 사용 오류를 인코더에 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(result, forKey: .result)
		try container.encode(message, forKey: .message)
		try container.encode(usage, forKey: .usage)
	}

	package var error: RunError {
		guard case let .errored(error) = result else {
			preconditionFailure("A CLI usage error requires an errored result.")
		}

		return error
	}

	// 사용 오류의 코딩 키를 나타냅니다.
	private enum CodingKeys: String, CodingKey {
		case result
		case message
		case usage
	}
}
