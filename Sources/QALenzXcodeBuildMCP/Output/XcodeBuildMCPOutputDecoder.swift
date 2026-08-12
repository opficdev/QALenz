//
//  XcodeBuildMCPOutputDecoder.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import QALenzCore

// XcodeBuildMCP JSON envelope를 검증해 공통 실행 결과로 변환합니다.
package struct XcodeBuildMCPOutputDecoder: Sendable {
	package let supportedSchemaVersions: [String: Set<String>]

	// 지원하는 schema와 version 집합으로 decoder를 구성합니다.
	package init(supportedSchemaVersions: [String: Set<String>]) {
		self.supportedSchemaVersions = supportedSchemaVersions
	}

	// JSON 응답의 구조와 schema version 및 오류 상태를 검증합니다.
	package func decode(
		_ data: Data,
		operation: XcodeBuildMCPOperation
	) -> XcodeBuildMCPResult {
		let envelope: XcodeBuildMCPEnvelope

		do {
			envelope = try decodeEnvelope(data)
		} catch {
			return failure(
				operation: operation,
				code: "adapter.xcodebuildmcp.output.invalid"
			)
		}

		guard supportedSchemaVersions[envelope.schema]?
			.contains(envelope.schemaVersion) == true else {
			return failure(
				operation: operation,
				code: "adapter.xcodebuildmcp.schema.unsupported"
			)
		}

		guard isValid(envelope) else {
			return failure(
				operation: operation,
				code: "adapter.xcodebuildmcp.output.invalid"
			)
		}

		guard !envelope.didError else {
			return failure(
				operation: operation,
				code: "adapter.xcodebuildmcp.command.failed"
			)
		}

		return .init(
			operation: operation,
			result: .passed,
			payload: envelope.data
		)
	}

	// 원본 JSON data를 XcodeBuildMCP 공통 envelope로 해석합니다.
	func decodeEnvelope(_ data: Data) throws -> XcodeBuildMCPEnvelope {
		try JSONDecoder().decode(XcodeBuildMCPEnvelope.self, from: data)
	}

	// 성공 여부와 error 및 data 조합이 일관되는지 판별합니다.
	private func isValid(_ envelope: XcodeBuildMCPEnvelope) -> Bool {
		if envelope.didError {
			guard let error = envelope.error else { return false }

			return !error.isEmpty && containsObjectOrNoData(envelope.data)
		}

		return envelope.error == nil && containsObjectOrNoData(envelope.data)
	}

	// data가 없거나 JSON object인지 판별합니다.
	private func containsObjectOrNoData(
		_ data: XcodeBuildMCPPayload?
	) -> Bool {
		guard let data else { return true }

		if case .object = data {
			return true
		}

		return false
	}

	// 원본 응답 내용을 포함하지 않는 adapter 실패 결과를 생성합니다.
	private func failure(
		operation: XcodeBuildMCPOperation,
		code: String
	) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(
				.init(
					kind: .adapter,
					code: .init(rawValue: code),
					context: .init(command: operation.rawValue)
				)
			)
		)
	}
}
