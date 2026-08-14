//
//  ScenarioJSONParser.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// Scenario JSON의 원문 숫자를 포함하는 중간 JSON 값을 표현합니다.
indirect enum ScenarioJSONValue: Equatable {
	case object([String: Self])
	case array([Self])
	case string(String)
	case number(String)
	case boolean(Bool)
	case null
}

// Scenario JSON 구문 해석 실패를 구분합니다.
enum ScenarioJSONSyntaxError: Error {
	case invalid
}

// Scenario JSON bytes를 숫자 원문 보존 중간 값으로 해석합니다.
struct ScenarioJSONParser {
	private let bytes: [UInt8]
	private var index = 0

	// 원본 JSON bytes로 parser를 구성합니다.
	init(data: Data) {
		bytes = Array(data)
	}

	// JSON 문서 전체를 하나의 중간 값으로 해석합니다.
	mutating func parse() throws -> ScenarioJSONValue {
		skipWhitespace()
		let value = try parseValue()
		skipWhitespace()
		guard index == bytes.count else { throw ScenarioJSONSyntaxError.invalid }

		return value
	}

	// 현재 위치의 JSON 값 하나를 해석합니다.
	private mutating func parseValue() throws -> ScenarioJSONValue {
		guard let current else { throw ScenarioJSONSyntaxError.invalid }

		switch current {
		case 0x7B:
			return try parseObject()
		case 0x5B:
			return try parseArray()
		case 0x22:
			return .string(try parseString())
		case 0x74:
			try parseLiteral([0x74, 0x72, 0x75, 0x65])
			return .boolean(true)
		case 0x66:
			try parseLiteral([0x66, 0x61, 0x6C, 0x73, 0x65])
			return .boolean(false)
		case 0x6E:
			try parseLiteral([0x6E, 0x75, 0x6C, 0x6C])
			return .null
		case 0x2D, 0x30...0x39:
			return .number(try parseNumber())
		default:
			throw ScenarioJSONSyntaxError.invalid
		}
	}

	// JSON object를 key와 값의 dictionary로 해석합니다.
	private mutating func parseObject() throws -> ScenarioJSONValue {
		try consume(0x7B)
		skipWhitespace()
		var object = [String: ScenarioJSONValue]()

		if consumeIf(0x7D) {
			return .object(object)
		}

		while true {
			skipWhitespace()
			guard current == 0x22 else { throw ScenarioJSONSyntaxError.invalid }
			let key = try parseString()
			skipWhitespace()
			try consume(0x3A)
			skipWhitespace()
			object[key] = try parseValue()
			skipWhitespace()

			if consumeIf(0x2C) {
				continue
			}
			try consume(0x7D)

			return .object(object)
		}
	}

	// JSON array를 입력 순서의 값 배열로 해석합니다.
	private mutating func parseArray() throws -> ScenarioJSONValue {
		try consume(0x5B)
		skipWhitespace()
		var array = [ScenarioJSONValue]()

		if consumeIf(0x5D) {
			return .array(array)
		}

		while true {
			skipWhitespace()
			array.append(try parseValue())
			skipWhitespace()

			if consumeIf(0x2C) {
				continue
			}
			try consume(0x5D)

			return .array(array)
		}
	}

	// JSON string bytes를 Foundation JSONDecoder로 검증하고 복원합니다.
	private mutating func parseString() throws -> String {
		let start = index
		try consume(0x22)

		while let current {
			switch current {
			case 0x22:
				index += 1
				do {
					return try JSONDecoder().decode(
						String.self,
						from: Data(Array(bytes[start..<index]))
					)
				} catch {
					throw ScenarioJSONSyntaxError.invalid
				}
			case 0x5C:
				index += 1
				guard self.current != nil else { throw ScenarioJSONSyntaxError.invalid }
				index += 1
			case 0x00...0x1F:
				throw ScenarioJSONSyntaxError.invalid
			default:
				index += 1
			}
		}

		throw ScenarioJSONSyntaxError.invalid
	}

	// JSON number 문법을 검증하며 입력한 숫자 원문을 반환합니다.
	private mutating func parseNumber() throws -> String {
		let start = index
		_ = consumeIf(0x2D)

		try parseIntegerPart()
		try parseFractionPart()
		try parseExponentPart()

		guard let literal = String(bytes: bytes[start..<index], encoding: .utf8) else {
			throw ScenarioJSONSyntaxError.invalid
		}

		return literal
	}

	// JSON number의 정수부를 검증하고 소비합니다.
	private mutating func parseIntegerPart() throws {
		guard let current else { throw ScenarioJSONSyntaxError.invalid }
		if current == 0x30 {
			index += 1
			return
		}
		guard isNonzeroDigit(current) else { throw ScenarioJSONSyntaxError.invalid }

		repeat {
			index += 1
		} while self.current.map(isDigit) == true
	}

	// JSON number의 소수부를 검증하고 소비합니다.
	private mutating func parseFractionPart() throws {
		guard consumeIf(0x2E) else { return }
		guard current.map(isDigit) == true else { throw ScenarioJSONSyntaxError.invalid }

		repeat {
			index += 1
		} while current.map(isDigit) == true
	}

	// JSON number의 지수부를 검증하고 소비합니다.
	private mutating func parseExponentPart() throws {
		guard current == 0x45 || current == 0x65 else { return }
		index += 1
		if current == 0x2B || current == 0x2D {
			index += 1
		}
		guard current.map(isDigit) == true else { throw ScenarioJSONSyntaxError.invalid }

		repeat {
			index += 1
		} while current.map(isDigit) == true
	}

	// 정해진 JSON literal을 현재 위치에서 소비합니다.
	private mutating func parseLiteral(_ literal: [UInt8]) throws {
		guard index + literal.count <= bytes.count else { throw ScenarioJSONSyntaxError.invalid }
		guard Array(bytes[index..<(index + literal.count)]) == literal else {
			throw ScenarioJSONSyntaxError.invalid
		}
		index += literal.count
	}

	// JSON에서 허용하는 공백 bytes를 건너뜁니다.
	private mutating func skipWhitespace() {
		while current == 0x20 || current == 0x09 || current == 0x0A || current == 0x0D {
			index += 1
		}
	}

	// 현재 위치가 기대한 byte인지 확인하고 소비합니다.
	private mutating func consume(_ expected: UInt8) throws {
		guard consumeIf(expected) else { throw ScenarioJSONSyntaxError.invalid }
	}

	// 현재 위치가 기대한 byte이면 소비하고 true를 반환합니다.
	private mutating func consumeIf(_ expected: UInt8) -> Bool {
		guard current == expected else { return false }
		index += 1

		return true
	}

	// 현재 parser 위치의 byte를 반환합니다.
	private var current: UInt8? {
		guard index < bytes.count else { return nil }

		return bytes[index]
	}

	// ASCII 숫자인지 반환합니다.
	private func isDigit(_ value: UInt8) -> Bool {
		(0x30...0x39).contains(value)
	}

	// 0이 아닌 ASCII 숫자인지 반환합니다.
	private func isNonzeroDigit(_ value: UInt8) -> Bool {
		(0x31...0x39).contains(value)
	}
}
