//
//  TargetValidatorTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Testing
@testable import QALenzCore

// 실행 대상 조합 입력 해석과 의미 검증 계약을 검증합니다.
@Suite
struct TargetValidatorTests {
	// 명시한 dimension과 누락 dimension의 기본값을 함께 정규화하는지 검증합니다.
	@Test
	func 명시한_dimension과_기본값을_정규화한다() throws {
		let definition = try TargetSelectionDecoder().decode(.object([
			"devices": .array([.string("iPhone 17")]),
			"languages": .array([.string("ko")])
		]))
		let resolved = try TargetValidator().validate(
			definition,
			defaults: defaults(),
			policy: policy()
		)

		#expect(resolved.devices == ["iPhone 17"])
		#expect(resolved.operatingSystems == ["iOS 26.0"])
		#expect(resolved.languages == ["ko"])
		#expect(resolved.appearances == ["light"])
	}

	// 지원하지 않는 dimension key를 명확한 오류로 거부하는지 검증합니다.
	@Test
	func 지원하지_않는_dimension_key를_거부한다() {
		#expect(throws: TargetValidationError.unsupportedDimension("device")) {
			try TargetSelectionDecoder().decode(.object([
				"device": .array([.string("iPhone 17")])
			]))
		}
	}

	// 배열이 아닌 dimension 값과 빈 배열을 구분해 거부하는지 검증합니다.
	@Test
	func 잘못된_dimension_형식과_빈_배열을_거부한다() {
		#expect(throws: TargetValidationError.dimensionInvalid(.languages)) {
			try TargetSelectionDecoder().decode(.object([
				"languages": .string("ko")
			]))
		}
		#expect(throws: TargetValidationError.dimensionEmpty(.appearances)) {
			try TargetSelectionDecoder().decode(.object([
				"appearances": .array([])
			]))
		}
	}

	// 공백뿐인 dimension 값과 지원하지 않는 device–OS 조합을 거부하는지 검증합니다.
	@Test
	func 빈_dimension_값과_지원하지_않는_device_OS_조합을_거부한다() {
		#expect(throws: TargetValidationError.valueEmpty(.devices, 0)) {
			try TargetValidator().validate(
				.init(devices: [" "]),
				defaults: defaults(),
				policy: policy()
			)
		}
		#expect(throws: TargetValidationError.deviceOperatingSystemUnsupported(
			device: "iPhone 17",
			operatingSystem: "iOS 25.0"
		)) {
			try TargetValidator().validate(
				.init(
					devices: ["iPhone 17"],
					operatingSystems: ["iOS 25.0"]
				),
				defaults: defaults(),
				policy: policy()
			)
		}
	}

	// project 기본값을 반환합니다.
	private func defaults() -> TargetDefaults {
		.init(
			devices: ["iPhone 16"],
			operatingSystems: ["iOS 26.0"],
			languages: ["en"],
			appearances: ["light"]
		)
	}

	// 허용하는 device–OS 조합을 반환합니다.
	private func policy() -> TargetPolicy {
		.init(
			allowedDeviceOperatingSystems: [
				.init(device: "iPhone 16", operatingSystem: "iOS 26.0"),
				.init(device: "iPhone 17", operatingSystem: "iOS 26.0")
			],
			maximumTargetCount: 12
		)
	}
}
