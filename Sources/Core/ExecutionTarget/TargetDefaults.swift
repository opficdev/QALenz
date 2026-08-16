//
//  TargetDefaults.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 누락한 실행 dimension에 적용할 project 기본값을 표현합니다.
package struct TargetDefaults: Codable, Sendable, Equatable {
	package let devices: [String]
	package let operatingSystems: [String]

	// 각 dimension의 project 기본값으로 초기화합니다.
	package init(
		devices: [String],
		operatingSystems: [String]
	) {
		self.devices = devices
		self.operatingSystems = operatingSystems
	}
}
