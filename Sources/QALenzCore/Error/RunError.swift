//
//  RunError.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct RunError: Error, Codable, Sendable, Equatable {
	package let kind: Kind
	package let code: Code
	package let context: Context

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

extension RunError {
	package enum Kind: String, Codable, Sendable, Equatable {
		case configuration
		case adapter
		case execution
		case evidence
		case verdict
		case report
	}

	package struct Code: RawRepresentable, Codable, Sendable, Equatable {
		package let rawValue: String

		package init(rawValue: String) {
			self.rawValue = rawValue
		}

		package init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()

			rawValue = try container.decode(String.self)
		}

		package func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()

			try container.encode(rawValue)
		}
	}

	package struct Context: Codable, Sendable, Equatable {
		package let command: String?
		package let target: String?
		package let step: String?
		package let assertion: String?

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
