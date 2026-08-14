//
//  ExecutionMatrixDefinition.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// scenario가 지정한 실행 dimension의 원본 값을 표현합니다.
package struct ExecutionMatrixDefinition: Sendable, Equatable {
	package let devices: [String]?
	package let operatingSystems: [String]?
	package let languages: [String]?
	package let appearances: [String]?

	// 선택한 dimension 값으로 실행 행렬 정의를 구성합니다.
	package init(
		devices: [String]? = nil,
		operatingSystems: [String]? = nil,
		languages: [String]? = nil,
		appearances: [String]? = nil
	) {
		self.devices = devices
		self.operatingSystems = operatingSystems
		self.languages = languages
		self.appearances = appearances
	}
}
