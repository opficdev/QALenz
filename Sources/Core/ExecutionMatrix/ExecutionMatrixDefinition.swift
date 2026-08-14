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

// 실행 행렬이 지원하는 dimension과 고정 처리 순서를 정의합니다.
package enum ExecutionMatrixDimension: String, CaseIterable, Sendable, Equatable {
	case devices
	case operatingSystems
	case languages
	case appearances
}

// 기본값 적용과 의미 검증을 마친 실행 dimension 값을 표현합니다.
package struct ExecutionMatrixResolvedDefinition: Sendable, Equatable {
	package let devices: [String]
	package let operatingSystems: [String]
	package let languages: [String]
	package let appearances: [String]

	// 모든 dimension의 검증된 값으로 초기화합니다.
	package init(
		devices: [String],
		operatingSystems: [String],
		languages: [String],
		appearances: [String]
	) {
		self.devices = devices
		self.operatingSystems = operatingSystems
		self.languages = languages
		self.appearances = appearances
	}
}
