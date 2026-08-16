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
		let targetDefaultsProperty = try #require(properties["targetDefaults"])
		let targetDefaultProperties = try #require(
			targetDefaultsProperty["properties"] as? [String: [String: Any]]
		)
		let maximumTargetCountProperty = try #require(properties["maximumTargetCount"])

		#expect(schema["type"] as? String == "object")
		#expect(requiredKeyNames == QALenzConfigurationDocument.requiredKeyNames)
		#expect(Set(properties.keys) == Set(QALenzConfigurationDocument.keyNames))
		#expect(schemaVersionProperty["type"] as? String == "integer")
		#expect(
			schemaVersionProperty["const"] as? Int
				== QALenzConfiguration.supportedSchemaVersion
		)

		for key in ["projectRoot", "xcodeBuildMCPProfile", "scenariosDirectory", "outputDirectory"] {
			let property = try #require(properties[key])

			#expect(property["type"] as? String == "string")
		}

		#expect(targetDefaultsProperty["type"] as? String == "object")
		#expect(targetDefaultsProperty["additionalProperties"] as? Bool == false)
		#expect(Set(targetDefaultProperties.keys) == ["devices", "operatingSystems"])
		for property in targetDefaultProperties.values {
			let items = try #require(property["items"] as? [String: Any])

			#expect(property["type"] as? String == "array")
			#expect(property["minItems"] as? Int == 1)
			#expect(items["type"] as? String == "string")
			#expect(items["minLength"] as? Int == 1)
		}
		#expect(maximumTargetCountProperty["type"] as? String == "integer")
		#expect(maximumTargetCountProperty["minimum"] as? Int == 1)
	}

	// bundle의 JSON Schema를 dictionary로 해석합니다.
	private func schemaObject() throws -> [String: Any] {
		let resourceURL = try #require(QALenzConfigurationSchema.resourceURL)
		let data = try Data(contentsOf: resourceURL)

		return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
	}
}
