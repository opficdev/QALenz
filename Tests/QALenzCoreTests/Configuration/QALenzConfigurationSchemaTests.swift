//
//  QALenzConfigurationSchemaTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore

// QALenz configuration JSON Schema와 decoder 입력 모델의 일치 여부를 검증합니다.
@Suite
struct QALenzConfigurationSchemaTests {
	// JSON Schema의 필수 key와 property가 decoder 입력 모델과 일치하는지 검증합니다.
	@Test
	func JSON_Schema가_decoder_입력_모델과_일치한다() throws {
		let schema = try schemaObject()
		let requiredKeyNames = try #require(schema["required"] as? [String])
		let properties = try #require(schema["properties"] as? [String: [String: Any]])
		let schemaVersionProperty = try #require(properties["schemaVersion"])

		#expect(schema["type"] as? String == "object")
		#expect(requiredKeyNames == QALenzConfigurationDocument.requiredKeyNames)
		#expect(Set(properties.keys) == Set(QALenzConfigurationDocument.keyNames))
		#expect(schemaVersionProperty["type"] as? String == "integer")
		#expect(
			schemaVersionProperty["const"] as? Int
				== QALenzConfiguration.supportedSchemaVersion
		)

		for key in QALenzConfigurationDocument.keyNames where key != "schemaVersion" {
			let property = try #require(properties[key])

			#expect(property["type"] as? String == "string")
		}
	}

	// bundle의 JSON Schema를 dictionary로 해석합니다.
	private func schemaObject() throws -> [String: Any] {
		let resourceURL = try #require(QALenzConfigurationSchema.resourceURL)
		let data = try Data(contentsOf: resourceURL)

		return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
	}
}
