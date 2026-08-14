//
//  TargetSelectionTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Testing
@testable import QALenzCore

// 실행 대상 조합 dimension 계약이 입력 순서와 정책 값을 보존하는지 검증합니다.
@Suite
struct TargetSelectionTests {
	// 모든 dimension 값을 제공하면 입력 순서와 기본값을 보존하는지 검증합니다.
	@Test
	func dimension_계약이_입력_순서와_기본값을_보존한다() {
		let definition = TargetSelection(
			devices: ["iPhone 17 Pro", "iPhone 17"],
			operatingSystems: ["iOS 26.0"],
			languages: ["ko", "en"],
			appearances: ["dark", "light"]
		)
		let defaults = TargetDefaults(
			devices: ["iPhone 16"],
			operatingSystems: ["iOS 25.0"],
			languages: ["en"],
			appearances: ["light"]
		)

		#expect(definition.devices == ["iPhone 17 Pro", "iPhone 17"])
		#expect(definition.operatingSystems == ["iOS 26.0"])
		#expect(definition.languages == ["ko", "en"])
		#expect(definition.appearances == ["dark", "light"])
		#expect(defaults.devices == ["iPhone 16"])
		#expect(defaults.operatingSystems == ["iOS 25.0"])
		#expect(defaults.languages == ["en"])
		#expect(defaults.appearances == ["light"])
	}

	// 지원 가능한 device와 operatingSystem 쌍 및 target 상한을 정책으로 보존하는지 검증합니다.
	@Test
	func 정책이_지원_쌍과_target_상한을_보존한다() {
		let supportedPair = TargetDeviceOperatingSystem(
			device: "iPhone 17",
			operatingSystem: "iOS 26.0"
		)
		let policy = TargetPolicy(
			allowedDeviceOperatingSystems: [supportedPair],
			maximumTargetCount: 12
		)

		#expect(policy.allowedDeviceOperatingSystems == [supportedPair])
		#expect(policy.maximumTargetCount == 12)
	}
}
