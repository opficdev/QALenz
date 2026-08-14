//
//  TargetValidator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 기본값 적용 뒤 실행 대상 조합의 의미를 검증합니다.
package struct TargetValidator: Sendable {
	// 기본 검증기를 구성합니다.
	package init() {}

	// 정의와 기본값을 검증된 실행 dimension 값으로 정규화합니다.
	package func validate(
		_ definition: TargetSelection,
		defaults: TargetDefaults,
		policy: TargetPolicy
	) throws -> ResolvedTargetSelection {
		let resolved = ResolvedTargetSelection(
			devices: definition.devices ?? defaults.devices,
			operatingSystems: definition.operatingSystems ?? defaults.operatingSystems,
			languages: definition.languages ?? defaults.languages,
			appearances: definition.appearances ?? defaults.appearances
		)

		try validate(resolved.devices, for: .devices)
		try validate(resolved.operatingSystems, for: .operatingSystems)
		try validate(resolved.languages, for: .languages)
		try validate(resolved.appearances, for: .appearances)
		try validateDeviceOperatingSystems(resolved, policy: policy)

		return resolved
	}

	// dimension 값이 비어 있거나 공백뿐인지 검증합니다.
	private func validate(
		_ values: [String],
		for dimension: TargetDimension
	) throws {
		guard !values.isEmpty else {
			throw TargetValidationError.dimensionEmpty(dimension)
		}

		for (index, value) in values.enumerated() {
			guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
				throw TargetValidationError.valueEmpty(dimension, index)
			}
		}
	}

	// 주입한 허용 조합과 device 및 operatingSystem 조합을 비교합니다.
	private func validateDeviceOperatingSystems(
		_ definition: ResolvedTargetSelection,
		policy: TargetPolicy
	) throws {
		guard let allowedPairs = policy.allowedDeviceOperatingSystems else { return }

		for device in definition.devices {
			for operatingSystem in definition.operatingSystems {
				let pair = TargetDeviceOperatingSystem(
					device: device,
					operatingSystem: operatingSystem
				)
				guard allowedPairs.contains(pair) else {
					throw TargetValidationError.deviceOperatingSystemUnsupported(
						device: device,
						operatingSystem: operatingSystem
					)
				}
			}
		}
	}
}
