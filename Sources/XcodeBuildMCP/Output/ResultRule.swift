//
//  ResultRule.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// 정규화된 payload에서 최종 실행 결과를 판정하는 규칙을 표현합니다.
package enum ResultRule: Sendable {
	case passed
	case summaryStatus

	// 판정 규칙에 따라 payload를 공통 실행 결과로 변환합니다.
	package func normalizedResult(from payload: XcodeBuildMCPPayload?) throws -> RunResult {
		switch self {
		case .passed:
			return .passed
		case .summaryStatus:
			guard
				case let .object(data)? = payload,
				case let .object(summary)? = data["summary"],
				case let .string(status)? = summary["status"]
			else {
				throw ResultRuleError.invalid
			}

			switch status {
			case "SUCCEEDED":
				return .passed
			case "FAILED":
				return .failed
			default:
				throw ResultRuleError.invalid
			}
		}
	}
}

// payload의 결과 상태가 판정 규칙과 다름을 나타냅니다.
private enum ResultRuleError: Error {
	case invalid
}
