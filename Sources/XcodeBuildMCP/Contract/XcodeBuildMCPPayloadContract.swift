//
//  XcodeBuildMCPPayloadContract.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// JSON schema version과 성공 payload 정규화 계약을 연결합니다.
struct XcodeBuildMCPOutputContract: Sendable {
	let versions: Set<String>
	let payload: XcodeBuildMCPPayloadContract
	let result: XcodeBuildMCPOutputResultContract

	// JSON version과 payload 및 결과 판정 계약을 구성합니다.
	init(
		versions: Set<String>,
		payload: XcodeBuildMCPPayloadContract,
		result: XcodeBuildMCPOutputResultContract = .passed
	) {
		self.versions = versions
		self.payload = payload
		self.result = result
	}
}

// 정규화된 payload에서 최종 실행 결과를 판정하는 규칙을 표현합니다.
enum XcodeBuildMCPOutputResultContract: Sendable {
	case passed
	case summaryStatus

	// 판정 규칙에 따라 payload를 공통 실행 결과로 변환합니다.
	func normalizedResult(
		from payload: XcodeBuildMCPPayload?
	) throws -> RunResult {
		switch self {
		case .passed:
			return .passed
		case .summaryStatus:
			guard
				case let .object(data)? = payload,
				case let .object(summary)? = data["summary"],
				case let .string(status)? = summary["status"]
			else {
				throw XcodeBuildMCPOutputResultContractError.invalid
			}

			switch status {
			case "SUCCEEDED":
				return .passed
			case "FAILED":
				return .failed
			default:
				throw XcodeBuildMCPOutputResultContractError.invalid
			}
		}
	}
}

// 성공 payload의 필수 여부와 허용 구조를 보관합니다.
struct XcodeBuildMCPPayloadContract: Sendable {
	let isRequired: Bool
	let schema: XcodeBuildMCPPayloadSchema

	// raw payload를 허용된 구조로 투영하고 구조가 다르면 거부합니다.
	func projected(
		_ payload: XcodeBuildMCPPayload?
	) throws -> XcodeBuildMCPPayload? {
		guard let payload else {
			guard !isRequired else {
				throw XcodeBuildMCPPayloadContractError.invalid
			}

			return nil
		}

		return try schema.projected(payload)
	}
}

// payload에서 허용할 scalar, array 및 object 구조를 표현합니다.
indirect enum XcodeBuildMCPPayloadSchema: Sendable {
	case scalar
	case array(element: Self)
	case object(fields: [String: Self], requiredFields: Set<String>)

	// raw payload에서 schema에 포함된 필드만 재귀적으로 투영합니다.
	func projected(
		_ payload: XcodeBuildMCPPayload
	) throws -> XcodeBuildMCPPayload {
		switch (self, payload) {
		case (.scalar, .string),
			(.scalar, .integer),
			(.scalar, .unsignedInteger),
			(.scalar, .number),
			(.scalar, .boolean):
			return payload
		case let (.array(schema), .array(values)):
			return try .array(values.map(schema.projected))
		case let (.object(fields, requiredFields), .object(values)):
			guard requiredFields.isSubset(of: values.keys) else {
				throw XcodeBuildMCPPayloadContractError.invalid
			}

			var projectedValues: [String: XcodeBuildMCPPayload] = [:]
			for (key, schema) in fields {
				guard let value = values[key] else { continue }

				projectedValues[key] = try schema.projected(value)
			}

			return .object(projectedValues)
		default:
			throw XcodeBuildMCPPayloadContractError.invalid
		}
	}
}

// payload가 operation별 허용 구조와 다름을 나타냅니다.
private enum XcodeBuildMCPPayloadContractError: Error {
	case invalid
}

// payload의 결과 상태가 계약과 다름을 나타냅니다.
private enum XcodeBuildMCPOutputResultContractError: Error {
	case invalid
}
