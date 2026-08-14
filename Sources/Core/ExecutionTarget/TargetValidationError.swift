//
//  TargetValidationError.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 실행 대상 조합 입력의 형식과 의미 검증 오류를 구분합니다.
package enum TargetValidationError: Error, Sendable, Equatable {
	case matrixInvalid
	case unsupportedDimension(String)
	case dimensionInvalid(TargetDimension)
	case dimensionEmpty(TargetDimension)
	case valueEmpty(TargetDimension, Int)
	case deviceOperatingSystemUnsupported(device: String, operatingSystem: String)
	case maximumTargetCountInvalid(Int)
	case targetCountExceeded(maximum: Int)
}
