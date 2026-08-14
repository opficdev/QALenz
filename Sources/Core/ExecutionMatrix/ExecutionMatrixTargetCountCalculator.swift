//
//  ExecutionMatrixTargetCountCalculator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 실행 target 수를 overflow 없이 계산하고 상한을 검증합니다.
package struct ExecutionMatrixTargetCountCalculator: Sendable {
	// 기본 계산기를 구성합니다.
	package init() {}

	// dimension별 값 개수의 곱을 상한 이내에서 계산합니다.
	package func calculate(
		dimensionCounts: [Int],
		maximumTargetCount: Int
	) throws -> Int {
		guard 0 < maximumTargetCount else {
			throw ExecutionMatrixValidationError.maximumTargetCountInvalid(maximumTargetCount)
		}

		var targetCount = 1

		for dimensionCount in dimensionCounts {
			let product = targetCount.multipliedReportingOverflow(by: dimensionCount)
			guard !product.overflow, product.partialValue <= maximumTargetCount else {
				throw ExecutionMatrixValidationError.targetCountExceeded(
					maximum: maximumTargetCount
				)
			}

			targetCount = product.partialValue
		}

		return targetCount
	}
}
