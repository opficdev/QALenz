//
//  RunResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

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

	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(status, forKey: .status)
		if case let .errored(error) = self {
			try container.encode(error, forKey: .error)
		}
	}

	private static func ensureErrorIsAbsent(
		in container: KeyedDecodingContainer<CodingKeys>
	) throws {
		guard !container.contains(.error) else {
			throw DecodingError.dataCorruptedError(
				forKey: .error,
				in: container,
				debugDescription: "An error is valid only when status is errored."
			)
		}
	}

	private enum CodingKeys: String, CodingKey {
		case status
		case error
	}
}

extension RunResult {
	package enum Status: String, Codable, Sendable, Equatable {
		case passed
		case failed
		case errored
	}
}
