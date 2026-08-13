//
//  PayloadSchema.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// payload에서 허용할 scalar, array 및 object 구조를 표현합니다.
package indirect enum PayloadSchema: Sendable {
	case scalar
	case array(element: Self)
	case object(fields: [String: Self], requiredFields: Set<String>)

	// raw payload에서 schema에 포함된 필드만 재귀적으로 투영합니다.
	package func projected(_ payload: XcodeBuildMCPPayload) throws -> XcodeBuildMCPPayload {
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
				throw PayloadDefinitionError.invalid
			}

			var projectedValues: [String: XcodeBuildMCPPayload] = [:]
			for (key, schema) in fields {
				guard let value = values[key] else { continue }

				projectedValues[key] = try schema.projected(value)
			}

			return .object(projectedValues)
		default:
			throw PayloadDefinitionError.invalid
		}
	}
}
