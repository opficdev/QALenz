//
//  RunResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

// QA 실행의 최종 상태를 나타냅니다.
package enum RunResult: Codable, Sendable, Equatable {
	case passed
	case failed
	case errored(RunError)

	package var status: Status {
		switch self {
		case .passed:
			.passed
		case .failed:
			.failed
		case .errored:
			.errored
		}
	}

	// 디코더에서 실행 결과를 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let status = try container.decode(Status.self, forKey: .status)

		switch status {
		case .passed:
			try Self.ensureErrorIsAbsent(in: container)
			self = .passed
		case .failed:
			try Self.ensureErrorIsAbsent(in: container)
			self = .failed
		case .errored:
			self = try .errored(container.decode(RunError.self, forKey: .error))
		}
	}

	// 실행 결과를 인코더에 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(status, forKey: .status)
		if case let .errored(error) = self {
			try container.encode(error, forKey: .error)
		}
	}

	// 성공 및 실패 결과에 오류가 없는지 검증합니다.
	private static func ensureErrorIsAbsent(in container: KeyedDecodingContainer<CodingKeys>) throws {
		guard !container.contains(.error) else {
			throw DecodingError.dataCorruptedError(
				forKey: .error,
				in: container,
				debugDescription: "An error is valid only when status is errored."
			)
		}
	}

	// 실행 결과의 코딩 키를 나타냅니다.
	private enum CodingKeys: String, CodingKey {
		case status
		case error
	}
}

// 실행 결과 구성에 필요한 중첩 타입을 정의합니다.
extension RunResult {
	// 실행 결과의 상태 값을 나타냅니다.
	package enum Status: String, Codable, Sendable, Equatable {
		case passed
		case failed
		case errored
	}
}
