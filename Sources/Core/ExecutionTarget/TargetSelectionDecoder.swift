//
//  TargetSelectionDecoder.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// ScenarioValue의 matrix 객체를 실행 대상 조합 입력 계약으로 해석합니다.
package struct TargetSelectionDecoder: Sendable {
	// 기본 decoder를 구성합니다.
	package init() {}

	// matrix JSON 값을 dimension별 선택 배열로 해석합니다.
	package func decode(_ value: ScenarioValue) throws -> TargetSelection {
		guard case .object(let matrixValues) = value else {
			throw TargetValidationError.matrixInvalid
		}

		for key in matrixValues.keys {
			guard TargetDimension(rawValue: key) != nil else {
				throw TargetValidationError.unsupportedDimension(key)
			}
		}

		return .init(
			devices: try values(for: .devices, in: matrixValues),
			operatingSystems: try values(for: .operatingSystems, in: matrixValues)
		)
	}

	// 한 dimension의 선택 배열을 해석합니다.
	private func values(
		for dimension: TargetDimension,
		in values: [String: ScenarioValue]
	) throws -> [String]? {
		guard let value = values[dimension.rawValue] else { return nil }
		guard case .array(let entries) = value else {
			throw TargetValidationError.dimensionInvalid(dimension)
		}
		guard !entries.isEmpty else {
			throw TargetValidationError.dimensionEmpty(dimension)
		}

		return try entries.map {
			guard case .string(let value) = $0 else {
				throw TargetValidationError.dimensionInvalid(dimension)
			}

			return value
		}
	}
}
