//
//  XcodeBuildMCPEventDecoder.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import QALenzCore

package struct XcodeBuildMCPEventDecoder: Sendable {
	private var buffer = Data()

	package init() {}

	package mutating func decode(
		_ data: Data,
		operation: XcodeBuildMCPOperation
	) throws -> [XcodeBuildMCPEvent] {
		buffer.append(data)
		var events: [XcodeBuildMCPEvent] = []

		while let newline = buffer.firstIndex(of: 0x0A) {
			let line = buffer[..<newline]
			buffer.removeSubrange(...newline)

			if let event = try event(from: Data(line), operation: operation) {
				events.append(event)
			}
		}

		return events
	}

	package mutating func finish(
		operation: XcodeBuildMCPOperation
	) throws -> [XcodeBuildMCPEvent] {
		guard !buffer.isEmpty else { return [] }

		let line = buffer
		buffer.removeAll(keepingCapacity: false)

		guard let event = try event(from: line, operation: operation) else {
			return []
		}

		return [event]
	}

	private func event(
		from data: Data,
		operation: XcodeBuildMCPOperation
	) throws -> XcodeBuildMCPEvent? {
		guard data.contains(where: { !$0.isJSONLineWhitespace }) else {
			return nil
		}

		let event: Event

		do {
			event = try JSONDecoder().decode(Event.self, from: data)
		} catch {
			throw invalidOutputError(operation: operation)
		}

		guard !event.event.isEmpty else {
			throw invalidOutputError(operation: operation)
		}

		return .init(
			operation: operation,
			kind: kind(for: event.event),
			message: event.message ?? event.status
		)
	}

	private func kind(for name: String) -> XcodeBuildMCPEvent.Kind {
		guard let component = name.split(separator: ".").last else {
			return .progress
		}

		if component == "invocation" {
			return .started
		}
		if component.hasSuffix("summary") {
			return .completed
		}

		return .progress
	}

	private func invalidOutputError(
		operation: XcodeBuildMCPOperation
	) -> RunError {
		.init(
			kind: .adapter,
			code: .init(rawValue: "adapter.xcodebuildmcp.output.invalid"),
			context: .init(command: operation.rawValue)
		)
	}

	private struct Event: Decodable {
		let event: String
		let message: String?
		let status: String?
	}
}

private extension UInt8 {
	var isJSONLineWhitespace: Bool {
		self == 0x09 || self == 0x0D || self == 0x20
	}
}
