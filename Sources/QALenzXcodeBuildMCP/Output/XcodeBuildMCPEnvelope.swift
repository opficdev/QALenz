//
//  XcodeBuildMCPEnvelope.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation

struct XcodeBuildMCPEnvelope: Decodable, Sendable, Equatable {
	let schema: String
	let schemaVersion: String
	let didError: Bool
	let error: String?
	let data: XcodeBuildMCPJSONValue?
	let nextSteps: [String]?
}

indirect enum XcodeBuildMCPJSONValue: Decodable, Sendable, Equatable {
	case object([String: Self])
	case array([Self])
	case string(String)
	case number(Double)
	case boolean(Bool)
	case null

	init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()

		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .boolean(value)
		} else if let value = try? container.decode(Double.self) {
			self = .number(value)
		} else if let value = try? container.decode(String.self) {
			self = .string(value)
		} else if let value = try? container.decode([Self].self) {
			self = .array(value)
		} else {
			self = try .object(container.decode([String: Self].self))
		}
	}
}
