//
//  XcodeBuildMCPPayload.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation

// 검증된 XcodeBuildMCP 응답 data를 손실 없이 표현합니다.
package indirect enum XcodeBuildMCPPayload: Decodable, Sendable, Equatable {
	case object([String: Self])
	case array([Self])
	case string(String)
	case integer(Int64)
	case unsignedInteger(UInt64)
	case number(Decimal)
	case boolean(Bool)
	case null

	// 단일 값 container에서 JSON 값의 실제 종류를 판별해 변환합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()

		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .boolean(value)
		} else if let value = try? container.decode(Int64.self) {
			self = .integer(value)
		} else if let value = try? container.decode(UInt64.self) {
			self = .unsignedInteger(value)
		} else if let value = try? container.decode(Decimal.self) {
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
