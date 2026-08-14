//
//  ScenarioJSONCodec.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// Scenario JSON 원본 값의 형식 불일치 위치를 전달합니다.
struct ScenarioJSONDecodingError: Error {
	let keyPath: String
}

// ScenarioValue의 숫자 원문을 보존하며 scenario 문서를 해석합니다.
package struct ScenarioJSONDecoder: Sendable {
	// 기본 scenario JSON decoder를 구성합니다.
	package init() {}

	// JSON bytes를 ScenarioDocument 원본 구조로 해석합니다.
	package func decode(_ data: Data) throws -> ScenarioDocument {
		var parser = ScenarioJSONParser(data: data)
		let value = try parser.parse()

		return try ScenarioJSONDocumentDecoder().decode(value)
	}
}

// ScenarioValue의 숫자 원문을 JSON 숫자로 출력합니다.
package struct ScenarioJSONEncoder: Sendable {
	// 기본 scenario JSON encoder를 구성합니다.
	package init() {}

	// 검증을 마친 Scenario를 JSON bytes로 인코딩합니다.
	package func encode(_ scenario: Scenario) throws -> Data {
		try ScenarioJSONWriter().encode(scenario)
	}
}

// Scenario JSON 출력 중 발견한 잘못된 숫자 원문을 구분합니다.
enum ScenarioJSONEncodingError: Error {
	case numberInvalid
}

// 중간 JSON 값을 ScenarioDocument 원본 구조로 변환합니다.
private struct ScenarioJSONDocumentDecoder {
	// 최상위 JSON 값을 ScenarioDocument로 변환합니다.
	func decode(_ value: ScenarioJSONValue) throws -> ScenarioDocument {
		let object = try object(from: value, at: "$")

		return try .init(
			schemaVersion: optionalInteger(in: object, forKey: "schemaVersion", at: "$.schemaVersion"),
			id: optionalString(in: object, forKey: "id", at: "$.id"),
			name: optionalString(in: object, forKey: "name", at: "$.name"),
			profile: optionalString(in: object, forKey: "profile", at: "$.profile"),
			matrix: optionalMatrix(in: object, forKey: "matrix", at: "$.matrix"),
			steps: optionalSteps(in: object, forKey: "steps", at: "$.steps"),
			assertions: optionalReferences(in: object, forKey: "assertions", at: "$.assertions"),
			evidence: optionalReferences(in: object, forKey: "evidence", at: "$.evidence")
		)
	}

	// step JSON 값을 ScenarioStepDocument로 변환합니다.
	private func step(from value: ScenarioJSONValue, at keyPath: String) throws -> ScenarioStepDocument {
		let object = try object(from: value, at: keyPath)

		return try .init(
			id: optionalString(in: object, forKey: "id", at: "\(keyPath).id"),
			action: optionalString(in: object, forKey: "action", at: "\(keyPath).action"),
			selector: optionalSelector(in: object, forKey: "selector", at: "\(keyPath).selector"),
			parameters: optionalParameters(in: object, forKey: "parameters", at: "\(keyPath).parameters")
		)
	}

	// assertion 또는 evidence JSON 값을 ScenarioStepReferenceDocument로 변환합니다.
	private func reference(
		from value: ScenarioJSONValue,
		at keyPath: String
	) throws -> ScenarioStepReferenceDocument {
		let object = try object(from: value, at: keyPath)

		return try .init(
			afterStepID: optionalString(in: object, forKey: "afterStepID", at: "\(keyPath).afterStepID"),
			parameters: optionalParameters(in: object, forKey: "parameters", at: "\(keyPath).parameters")
		)
	}

	// selector JSON 값을 ScenarioSelector로 변환합니다.
	private func selector(from value: ScenarioJSONValue, at keyPath: String) throws -> ScenarioSelector {
		let object = try object(from: value, at: keyPath)
		let unknownKeyName = object.keys.sorted().first {
			!ScenarioSelector.keyNames.contains($0)
		}

		if let unknownKeyName {
			throw ScenarioJSONDecodingError(keyPath: "\(keyPath).\(unknownKeyName)")
		}

		return try .init(
			identifier: optionalString(in: object, forKey: "identifier", at: "\(keyPath).identifier"),
			label: optionalString(in: object, forKey: "label", at: "\(keyPath).label"),
			role: optionalString(in: object, forKey: "role", at: "\(keyPath).role"),
			value: optionalString(in: object, forKey: "value", at: "\(keyPath).value")
		)
	}

	// 중간 JSON 값을 ScenarioValue로 재귀 변환합니다.
	private func scenarioValue(from value: ScenarioJSONValue) throws -> ScenarioValue {
		switch value {
		case .object(let object):
			return .object(try object.mapValues { try scenarioValue(from: $0) })
		case .array(let array):
			return .array(try array.map { try scenarioValue(from: $0) })
		case .string(let value):
			return .string(value)
		case .number(let value):
			return .number(value)
		case .boolean(let value):
			return .boolean(value)
		case .null:
			return .null
		}
	}

	// 최상위 matrix를 선택 JSON 값으로 해석하고 명시적 null을 거부합니다.
	private func optionalMatrix(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> ScenarioValue? {
		guard let value = object[key] else { return nil }
		guard value != .null else { throw ScenarioJSONDecodingError(keyPath: keyPath) }

		return try scenarioValue(from: value)
	}

	// parameters의 명시적 null을 ScenarioValue.null로 보존합니다.
	private func optionalParameters(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> ScenarioValue? {
		guard let value = object[key] else { return nil }

		return try scenarioValue(from: value)
	}

	// steps 배열을 각 JSON index 문맥과 함께 변환합니다.
	private func optionalSteps(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> [ScenarioStepDocument]? {
		guard let values = try optionalArray(in: object, forKey: key, at: keyPath) else { return nil }

		return try values.enumerated().map { index, value in
			try step(from: value, at: "\(keyPath)[\(index)]")
		}
	}

	// assertion 또는 evidence 배열을 각 JSON index 문맥과 함께 변환합니다.
	private func optionalReferences(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> [ScenarioStepReferenceDocument]? {
		guard let values = try optionalArray(in: object, forKey: key, at: keyPath) else { return nil }

		return try values.enumerated().map { index, value in
			try reference(from: value, at: "\(keyPath)[\(index)]")
		}
	}

	// selector JSON object를 선택 값으로 해석하고 명시적 null을 거부합니다.
	private func optionalSelector(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> ScenarioSelector? {
		guard let value = object[key] else { return nil }

		return try selector(from: value, at: keyPath)
	}

	// JSON string을 선택 문자열로 해석하고 명시적 null을 거부합니다.
	private func optionalString(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> String? {
		guard let value = object[key] else { return nil }
		guard value != .null else { throw ScenarioJSONDecodingError(keyPath: keyPath) }
		guard case .string(let string) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return string
	}

	// JSON 정수를 선택 정수로 해석하고 명시적 null을 거부합니다.
	private func optionalInteger(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> Int? {
		guard let value = object[key] else { return nil }
		guard value != .null else { throw ScenarioJSONDecodingError(keyPath: keyPath) }
		guard case .number(let literal) = value, let integer = integer(from: literal) else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return integer
	}

	// JSON 숫자 원문이 정확한 Int 값이면 지수와 소수 표기도 정수로 변환합니다.
	private func integer(from literal: String) -> Int? {
		let negative = literal.first == "-"
		let unsigned = negative ? literal.dropFirst() : literal[...]
		let exponentParts = unsigned.split(
			maxSplits: 1,
			omittingEmptySubsequences: false,
			whereSeparator: { $0 == "e" || $0 == "E" }
		)
		let significand = exponentParts[0]
		let exponent = exponentParts.count == 2 ? Int(exponentParts[1]) : 0
		guard let exponent else { return nil }
		let fractionParts = significand.split(
			separator: ".",
			maxSplits: 1,
			omittingEmptySubsequences: false
		)
		let integerPart = fractionParts[0]
		let fractionPart = fractionParts.count == 2 ? fractionParts[1] : ""
		let scaleResult = fractionPart.count.subtractingReportingOverflow(exponent)
		guard !scaleResult.overflow else { return nil }

		let digits = integerPart + fractionPart
		let integerDigits: Substring
		if scaleResult.partialValue <= 0 {
			guard scaleResult.partialValue != .min else { return nil }
			let zeroCount = -scaleResult.partialValue
			let maximumDigits = String(Int.max).count
			guard zeroCount <= maximumDigits else { return nil }
			guard digits.count <= maximumDigits - zeroCount else { return nil }
			integerDigits = digits + String(repeating: "0", count: zeroCount)
		} else {
			guard scaleResult.partialValue <= digits.count else {
				return digits.allSatisfy { $0 == "0" } ? 0 : nil
			}
			guard digits.suffix(scaleResult.partialValue).allSatisfy({ $0 == "0" }) else {
				return nil
			}
			integerDigits = digits.dropLast(scaleResult.partialValue)
		}

		let magnitude = integerDigits.drop { $0 == "0" }
		let normalized = magnitude.isEmpty ? "0" : String(magnitude)

		return Int(negative ? "-\(normalized)" : normalized)
	}

	// JSON array를 선택 배열로 해석하고 명시적 null을 거부합니다.
	private func optionalArray(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> [ScenarioJSONValue]? {
		guard let value = object[key] else { return nil }
		guard value != .null else { throw ScenarioJSONDecodingError(keyPath: keyPath) }
		guard case .array(let array) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return array
	}

	// 중간 JSON 값이 object인지 검증합니다.
	private func object(
		from value: ScenarioJSONValue,
		at keyPath: String
	) throws -> [String: ScenarioJSONValue] {
		guard case .object(let object) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return object
	}
}

// Scenario를 중간 JSON 값으로 변환합니다.
extension ScenarioJSONValue {
	// Scenario의 모든 최상위 값을 중간 JSON object로 변환합니다.
	init(scenario: Scenario) {
		self = .object([
			"schemaVersion": .number(String(scenario.schemaVersion)),
			"id": .string(scenario.id),
			"name": .string(scenario.name),
			"profile": .string(scenario.profile),
			"matrix": .init(scenarioValue: scenario.matrix),
			"steps": .array(scenario.steps.map { .init(step: $0) }),
			"assertions": .array(scenario.assertions.map { .init(reference: $0) }),
			"evidence": .array(scenario.evidence.map { .init(reference: $0) })
		])
	}

	// ScenarioStep을 중간 JSON object로 변환합니다.
	init(step: ScenarioStep) {
		var object: [String: ScenarioJSONValue] = [
			"id": .string(step.id),
			"action": .string(step.action.rawValue)
		]

		if let selector = step.selector {
			object["selector"] = .init(selector: selector)
		}
		if let parameters = step.parameters {
			object["parameters"] = .init(scenarioValue: parameters)
		}
		self = .object(object)
	}

	// ScenarioStepReference를 중간 JSON object로 변환합니다.
	init(reference: ScenarioStepReference) {
		var object: [String: ScenarioJSONValue] = [
			"afterStepID": .string(reference.afterStepID)
		]

		if let parameters = reference.parameters {
			object["parameters"] = .init(scenarioValue: parameters)
		}
		self = .object(object)
	}

	// ScenarioSelector를 중간 JSON object로 변환합니다.
	init(selector: ScenarioSelector) {
		var object = [String: ScenarioJSONValue]()

		if let identifier = selector.identifier {
			object["identifier"] = .string(identifier)
		}
		if let label = selector.label {
			object["label"] = .string(label)
		}
		if let role = selector.role {
			object["role"] = .string(role)
		}
		if let value = selector.value {
			object["value"] = .string(value)
		}
		self = .object(object)
	}

	// ScenarioValue를 숫자 원문을 유지한 중간 JSON 값으로 변환합니다.
	init(scenarioValue: ScenarioValue) {
		switch scenarioValue {
		case .object(let object):
			self = .object(object.mapValues { .init(scenarioValue: $0) })
		case .array(let array):
			self = .array(array.map { .init(scenarioValue: $0) })
		case .string(let value):
			self = .string(value)
		case .number(let value):
			self = .number(value)
		case .boolean(let value):
			self = .boolean(value)
		case .null:
			self = .null
		}
	}
}
