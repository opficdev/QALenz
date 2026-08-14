//
//  TestDataRequirementJSONCodec.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

// test data 요구사항 JSON 값을 원본 문서 구조로 변환합니다.
struct TestDataRequirementJSONDocumentDecoder {
	// 최상위 object의 선택 배열을 원본 requirement 배열로 변환합니다.
	func decode(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> [TestDataRequirementDocument]? {
		guard let value = object[key] else { return nil }
		guard case .array(let values) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return try values.enumerated().map { index, value in
			try decode(value, at: "\(keyPath)[\(index)]")
		}
	}

	// requirement object의 선택 문자열을 원본 requirement로 변환합니다.
	private func decode(
		_ value: ScenarioJSONValue,
		at keyPath: String
	) throws -> TestDataRequirementDocument {
		guard case .object(let object) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}
		guard let unknownKeyName = object.keys.sorted().first(
			where: { $0 != "operation" && $0 != "resource" }
		) else {
			return try .init(
				operation: string(in: object, forKey: "operation", at: "\(keyPath).operation"),
				resource: string(in: object, forKey: "resource", at: "\(keyPath).resource")
			)
		}

		throw ScenarioJSONDecodingError(keyPath: "\(keyPath).\(unknownKeyName)")
	}

	// object의 선택 문자열을 해석하고 null과 다른 형식을 거부합니다.
	private func string(
		in object: [String: ScenarioJSONValue],
		forKey key: String,
		at keyPath: String
	) throws -> String? {
		guard let value = object[key] else { return nil }
		guard case .string(let string) = value else {
			throw ScenarioJSONDecodingError(keyPath: keyPath)
		}

		return string
	}
}

// TestDataRequirement를 중간 JSON object로 변환합니다.
extension ScenarioJSONValue {
	init(testDataRequirement: TestDataRequirement) {
		self = .object([
			"operation": .string(testDataRequirement.operation.rawValue),
			"resource": .string(testDataRequirement.resource)
		])
	}
}
