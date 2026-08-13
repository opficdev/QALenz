//
//  PayloadDefinition.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// 성공 payload의 필수 여부와 허용 구조를 보관합니다.
package struct PayloadDefinition: Sendable {
	package let isRequired: Bool
	package let schema: PayloadSchema

	// 필수 여부와 허용 schema로 payload 정의를 구성합니다.
	package init(isRequired: Bool, schema: PayloadSchema) {
		self.isRequired = isRequired
		self.schema = schema
	}

	// raw payload를 허용된 구조로 투영하고 구조가 다르면 거부합니다.
	package func projected(_ payload: XcodeBuildMCPPayload?) throws -> XcodeBuildMCPPayload? {
		guard let payload else {
			guard !isRequired else {
				throw PayloadDefinitionError.invalid
			}

			return nil
		}

		return try schema.projected(payload)
	}
}

// payload가 operation별 허용 구조와 다름을 나타냅니다.
enum PayloadDefinitionError: Error {
	case invalid
}
