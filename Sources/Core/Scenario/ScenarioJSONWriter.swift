//
//  ScenarioJSONWriter.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 중간 JSON 값을 유효한 Scenario JSON bytes로 출력합니다.
struct ScenarioJSONWriter {
	// Scenario를 원문 숫자를 보존한 JSON bytes로 인코딩합니다.
	func encode(_ scenario: Scenario) throws -> Data {
		var data = Data()
		try append(.init(scenario: scenario), to: &data)

		return data
	}

	// 중간 JSON 값을 재귀적으로 JSON bytes에 추가합니다.
	private func append(_ value: ScenarioJSONValue, to data: inout Data) throws {
		switch value {
		case .object(let object):
			try append(object: object, to: &data)
		case .array(let array):
			try append(array: array, to: &data)
		case .string(let string):
			try append(string: string, to: &data)
		case .number(let literal):
			try append(number: literal, to: &data)
		case .boolean(let value):
			data.append(contentsOf: value ? [0x74, 0x72, 0x75, 0x65] : [0x66, 0x61, 0x6C, 0x73, 0x65])
		case .null:
			data.append(contentsOf: [0x6E, 0x75, 0x6C, 0x6C])
		}
	}

	// JSON object의 key를 정렬한 뒤 출력합니다.
	private func append(object: [String: ScenarioJSONValue], to data: inout Data) throws {
		data.append(0x7B)

		for (index, key) in object.keys.sorted().enumerated() {
			if 0 < index {
				data.append(0x2C)
			}
			try append(string: key, to: &data)
			data.append(0x3A)
			guard let value = object[key] else { continue }
			try append(value, to: &data)
		}

		data.append(0x7D)
	}

	// JSON array를 입력 순서대로 출력합니다.
	private func append(array: [ScenarioJSONValue], to data: inout Data) throws {
		data.append(0x5B)

		for (index, value) in array.enumerated() {
			if 0 < index {
				data.append(0x2C)
			}
			try append(value, to: &data)
		}

		data.append(0x5D)
	}

	// JSON string escape 규칙을 Foundation JSONEncoder에 위임합니다.
	private func append(string: String, to data: inout Data) throws {
		data.append(try JSONEncoder().encode(string))
	}

	// 검증한 JSON 숫자 원문을 따옴표 없이 출력합니다.
	private func append(number literal: String, to data: inout Data) throws {
		var parser = ScenarioJSONParser(data: Data(literal.utf8))
		let value: ScenarioJSONValue

		do {
			value = try parser.parse()
		} catch {
			throw ScenarioJSONEncodingError.numberInvalid
		}
		guard case .number(let parsed) = value, parsed == literal else {
			throw ScenarioJSONEncodingError.numberInvalid
		}
		data.append(contentsOf: literal.utf8)
	}
}
