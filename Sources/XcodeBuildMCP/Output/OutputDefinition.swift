//
//  OutputDefinition.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// JSON schema version과 성공 payload 정규화 정의를 연결합니다.
package struct OutputDefinition: Sendable {
	package let versions: Set<String>
	package let payload: PayloadDefinition
	package let result: ResultRule

	// JSON version과 payload 및 결과 판정 정의를 구성합니다.
	package init(
		versions: Set<String>,
		payload: PayloadDefinition,
		result: ResultRule = .passed
	) {
		self.versions = versions
		self.payload = payload
		self.result = result
	}
}
