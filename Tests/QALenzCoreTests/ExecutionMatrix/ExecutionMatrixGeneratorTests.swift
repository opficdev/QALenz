//
//  ExecutionMatrixGeneratorTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Testing
@testable import QALenzCore

// 실행 target 조합과 재현 가능한 identifier 계약을 검증합니다.
@Suite
struct ExecutionMatrixGeneratorTests {
	// 모든 dimension의 Cartesian product를 고정 순서로 생성하는지 검증합니다.
	@Test
	func 모든_dimension의_Cartesian_product를_고정_순서로_생성한다() throws {
		let targets = try ExecutionMatrixGenerator().generate(
			.init(
				devices: ["iPhone 17", "iPhone 16"],
				operatingSystems: ["iOS 26.0"],
				languages: ["ko", "en"],
				appearances: ["dark", "light"]
			),
			defaults: defaults(),
			policy: .init(maximumTargetCount: 12)
		)

		#expect(targets.map(\.device) == [
			"iPhone 17", "iPhone 17", "iPhone 17", "iPhone 17",
			"iPhone 16", "iPhone 16", "iPhone 16", "iPhone 16"
		])
		#expect(targets.map(\.language) == ["ko", "ko", "en", "en", "ko", "ko", "en", "en"])
		#expect(targets.map(\.appearance) == ["dark", "light", "dark", "light", "dark", "light", "dark", "light"])
		#expect(targets.map(\.identifier) == [
			"device=9:iPhone 17|operatingSystem=8:iOS 26.0|language=2:ko|appearance=4:dark",
			"device=9:iPhone 17|operatingSystem=8:iOS 26.0|language=2:ko|appearance=5:light",
			"device=9:iPhone 17|operatingSystem=8:iOS 26.0|language=2:en|appearance=4:dark",
			"device=9:iPhone 17|operatingSystem=8:iOS 26.0|language=2:en|appearance=5:light",
			"device=9:iPhone 16|operatingSystem=8:iOS 26.0|language=2:ko|appearance=4:dark",
			"device=9:iPhone 16|operatingSystem=8:iOS 26.0|language=2:ko|appearance=5:light",
			"device=9:iPhone 16|operatingSystem=8:iOS 26.0|language=2:en|appearance=4:dark",
			"device=9:iPhone 16|operatingSystem=8:iOS 26.0|language=2:en|appearance=5:light"
		])
	}

	// 중복 dimension 값을 최초 등장 순서로 제거하고 같은 입력에 같은 target을 생성하는지 검증합니다.
	@Test
	func 중복_dimension을_제거하고_재현_가능한_target을_생성한다() throws {
		let definition = ExecutionMatrixDefinition(
			devices: ["iPhone 17", "iPhone 16", "iPhone 17"],
			languages: ["ko", "en", "ko"]
		)
		let generator = ExecutionMatrixGenerator()
		let first = try generator.generate(
			definition,
			defaults: defaults(),
			policy: .init(maximumTargetCount: 4)
		)
		let second = try generator.generate(
			definition,
			defaults: defaults(),
			policy: .init(maximumTargetCount: 4)
		)

		#expect(first == second)
		#expect(first.map(\.device) == ["iPhone 17", "iPhone 17", "iPhone 16", "iPhone 16"])
		#expect(first.map(\.language) == ["ko", "en", "ko", "en"])
	}

	// target 수 상한과 곱셈 overflow를 생성 전에 거부하는지 검증합니다.
	@Test
	func target_수_상한과_overflow를_생성_전에_거부한다() {
		#expect(throws: ExecutionMatrixValidationError.targetCountExceeded(maximum: 3)) {
			try ExecutionMatrixGenerator().generate(
				.init(devices: ["iPhone 17", "iPhone 16"], languages: ["ko", "en"]),
				defaults: defaults(),
				policy: .init(maximumTargetCount: 3)
			)
		}
		#expect(throws: ExecutionMatrixValidationError.targetCountExceeded(maximum: .max)) {
			try ExecutionMatrixTargetCountCalculator().calculate(
				dimensionCounts: [.max, 2],
				maximumTargetCount: .max
			)
		}
	}

	// project 기본값을 반환합니다.
	private func defaults() -> ExecutionMatrixDefaults {
		.init(
			devices: ["iPhone 16"],
			operatingSystems: ["iOS 26.0"],
			languages: ["en"],
			appearances: ["light"]
		)
	}
}
