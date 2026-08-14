//
//  ExecutionMatrixPolicy.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 하나의 device와 operatingSystem 조합을 표현합니다.
package struct ExecutionMatrixDeviceOperatingSystem: Hashable, Sendable {
	package let device: String
	package let operatingSystem: String

	// device와 operatingSystem 값으로 조합을 구성합니다.
	package init(device: String, operatingSystem: String) {
		self.device = device
		self.operatingSystem = operatingSystem
	}
}

// 실행 target 생성 전 적용할 제한과 허용 조합을 표현합니다.
package struct ExecutionMatrixPolicy: Sendable, Equatable {
	package let allowedDeviceOperatingSystems: Set<ExecutionMatrixDeviceOperatingSystem>?
	package let maximumTargetCount: Int

	// 허용 조합과 생성 가능한 target 수 상한으로 정책을 구성합니다.
	package init(
		allowedDeviceOperatingSystems: Set<ExecutionMatrixDeviceOperatingSystem>? = nil,
		maximumTargetCount: Int
	) {
		self.allowedDeviceOperatingSystems = allowedDeviceOperatingSystems
		self.maximumTargetCount = maximumTargetCount
	}
}
