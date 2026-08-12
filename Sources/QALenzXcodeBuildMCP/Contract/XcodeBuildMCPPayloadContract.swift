//
//  XcodeBuildMCPPayloadContract.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// JSON schema version과 성공 payload 정규화 계약을 연결합니다.
struct XcodeBuildMCPOutputContract: Sendable {
	let versions: Set<String>
	let payload: XcodeBuildMCPPayloadContract
}

// 성공 payload의 필수 여부와 허용 구조를 보관합니다.
struct XcodeBuildMCPPayloadContract: Sendable {
	let isRequired: Bool
	let schema: XcodeBuildMCPPayloadSchema

	// raw payload를 허용된 구조로 투영하고 구조가 다르면 거부합니다.
	func projected(
		_ payload: XcodeBuildMCPPayload?
	) throws -> XcodeBuildMCPPayload? {
		guard let payload else {
			guard !isRequired else {
				throw XcodeBuildMCPPayloadContractError.invalid
			}

			return nil
		}

		return try schema.projected(payload)
	}
}

// payload에서 허용할 scalar, array 및 object 구조를 표현합니다.
indirect enum XcodeBuildMCPPayloadSchema: Sendable {
	case scalar
	case array(element: Self)
	case object(fields: [String: Self], requiredFields: Set<String>)

	// raw payload에서 schema에 포함된 필드만 재귀적으로 투영합니다.
	func projected(
		_ payload: XcodeBuildMCPPayload
	) throws -> XcodeBuildMCPPayload {
		switch (self, payload) {
		case (.scalar, .string),
			(.scalar, .integer),
			(.scalar, .unsignedInteger),
			(.scalar, .number),
			(.scalar, .boolean):
			return payload
		case let (.array(schema), .array(values)):
			return try .array(values.map(schema.projected))
		case let (.object(fields, requiredFields), .object(values)):
			guard requiredFields.isSubset(of: values.keys) else {
				throw XcodeBuildMCPPayloadContractError.invalid
			}

			var projectedValues: [String: XcodeBuildMCPPayload] = [:]
			for (key, schema) in fields {
				guard let value = values[key] else { continue }

				projectedValues[key] = try schema.projected(value)
			}

			return .object(projectedValues)
		default:
			throw XcodeBuildMCPPayloadContractError.invalid
		}
	}
}

// payload가 operation별 허용 구조와 다름을 나타냅니다.
private enum XcodeBuildMCPPayloadContractError: Error {
	case invalid
}
