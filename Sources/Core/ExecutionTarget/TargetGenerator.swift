//
//  TargetGenerator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 검증한 실행 matrix를 중복 없는 순서의 실행 target으로 변환합니다.
package struct TargetGenerator: Sendable {
	// 기본 생성기를 구성합니다.
	package init() {}

	// 정의, 기본값, 정책을 실행 target 배열로 변환합니다.
	package func generate(
		_ definition: TargetSelection,
		defaults: TargetDefaults,
		policy: TargetPolicy
	) throws -> [Target] {
		let resolved = try TargetValidator().validate(
			definition,
			defaults: defaults,
			policy: policy
		)
		let devices = uniqueValues(in: resolved.devices)
		let operatingSystems = uniqueValues(in: resolved.operatingSystems)
		let languages = uniqueValues(in: resolved.languages)
		let appearances = uniqueValues(in: resolved.appearances)

		_ = try TargetCountCalculator().calculate(
			dimensionCounts: [
				devices.count,
				operatingSystems.count,
				languages.count,
				appearances.count
			],
			maximumTargetCount: policy.maximumTargetCount
		)

		return devices.flatMap { device in
			operatingSystems.flatMap { operatingSystem in
				languages.flatMap { language in
					appearances.map { appearance in
						Target(
							device: device,
							operatingSystem: operatingSystem,
							language: language,
							appearance: appearance
						)
					}
				}
			}
		}
	}

	// 최초 등장 순서를 보존하며 dimension 중복을 제거합니다.
	private func uniqueValues(in values: [String]) -> [String] {
		var knownValues = Set<String>()

		return values.filter { knownValues.insert($0).inserted }
	}
}
