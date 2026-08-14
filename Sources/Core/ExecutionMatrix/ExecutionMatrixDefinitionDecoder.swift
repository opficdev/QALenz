//
//  ExecutionMatrixDefinitionDecoder.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// ScenarioValue의 matrix 객체를 실행 행렬 입력 계약으로 해석합니다.
package struct ExecutionMatrixDefinitionDecoder: Sendable {
	// 기본 decoder를 구성합니다.
	package init() {}

	// matrix JSON 값을 dimension별 선택 배열로 해석합니다.
	package func decode(_ value: ScenarioValue) throws -> ExecutionMatrixDefinition {
		guard case .object(let matrixValues) = value else {
			throw ExecutionMatrixValidationError.matrixInvalid
		}

		for key in matrixValues.keys {
			guard ExecutionMatrixDimension(rawValue: key) != nil else {
				throw ExecutionMatrixValidationError.unsupportedDimension(key)
			}
		}

		return .init(
			devices: try values(for: .devices, in: matrixValues),
			operatingSystems: try values(for: .operatingSystems, in: matrixValues),
			languages: try values(for: .languages, in: matrixValues),
			appearances: try values(for: .appearances, in: matrixValues)
		)
	}

	// 한 dimension의 선택 배열을 해석합니다.
	private func values(
		for dimension: ExecutionMatrixDimension,
		in values: [String: ScenarioValue]
	) throws -> [String]? {
		guard let value = values[dimension.rawValue] else { return nil }
		guard case .array(let entries) = value else {
			throw ExecutionMatrixValidationError.dimensionInvalid(dimension)
		}
		guard !entries.isEmpty else {
			throw ExecutionMatrixValidationError.dimensionEmpty(dimension)
		}

		return try entries.map {
			guard case .string(let value) = $0 else {
				throw ExecutionMatrixValidationError.dimensionInvalid(dimension)
			}

			return value
		}
	}
}
