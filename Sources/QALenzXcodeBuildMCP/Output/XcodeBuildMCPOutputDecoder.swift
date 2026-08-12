//
//  XcodeBuildMCPOutputDecoder.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import QALenzCore

package struct XcodeBuildMCPOutputDecoder: Sendable {
	package let supportedSchemaVersions: [String: Set<String>]

	package init(supportedSchemaVersions: [String: Set<String>]) {
		self.supportedSchemaVersions = supportedSchemaVersions
	}

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

		return .init(operation: operation, result: .passed)
	}

	func decodeEnvelope(_ data: Data) throws -> XcodeBuildMCPEnvelope {
		try JSONDecoder().decode(XcodeBuildMCPEnvelope.self, from: data)
	}

	private func isValid(_ envelope: XcodeBuildMCPEnvelope) -> Bool {
		if envelope.didError {
			guard let error = envelope.error else { return false }

			return !error.isEmpty && containsObjectOrNoData(envelope.data)
		}

		return envelope.error == nil && containsObjectOrNoData(envelope.data)
	}

	private func containsObjectOrNoData(
		_ data: XcodeBuildMCPJSONValue?
	) -> Bool {
		guard let data else { return true }

		if case .object = data {
			return true
		}

		return false
	}

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
