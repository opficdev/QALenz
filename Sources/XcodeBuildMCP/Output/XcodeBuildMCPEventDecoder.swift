//
//  XcodeBuildMCPEventDecoder.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import QALenzCore

// 분할 수신된 JSONL 데이터를 QALenz 진행 사건으로 변환합니다.
package struct XcodeBuildMCPEventDecoder: Sendable {
	private var buffer = Data()
	private var terminalEvent: XcodeBuildMCPEvent?
	private let descriptor: EventDescriptor
	private let maximumLineByteCount: Int

	// JSONL event descriptor와 단일 레코드 최대 크기로 decoder를 구성합니다.
	init(
		descriptor: EventDescriptor,
		maximumLineByteCount: Int = 1_048_576
	) {
		precondition(0 < maximumLineByteCount)
		self.descriptor = descriptor
		self.maximumLineByteCount = maximumLineByteCount
	}

	// 새 데이터를 buffer에 추가하고 줄이 완성된 사건을 반환합니다.
	package mutating func decode(
		_ data: Data,
		operation: XcodeBuildMCPOperation
	) throws -> [XcodeBuildMCPEvent] {
		buffer.append(data)
		var events: [XcodeBuildMCPEvent] = []

		while let newline = buffer.firstIndex(of: 0x0A) {
			let line = buffer[..<newline]
			buffer.removeSubrange(...newline)
			guard line.count <= maximumLineByteCount else {
				throw invalidOutputError(operation: operation)
			}

			if let event = try event(from: Data(line), operation: operation) {
				events.append(event)
			}
		}
		guard buffer.count <= maximumLineByteCount else {
			throw invalidOutputError(operation: operation)
		}

		return events
	}

	// 줄바꿈 없이 남아 있는 마지막 JSONL 사건을 처리합니다.
	package mutating func finish(operation: XcodeBuildMCPOperation) throws -> [XcodeBuildMCPEvent] {
		var events = [XcodeBuildMCPEvent]()

		if !buffer.isEmpty {
			guard buffer.count <= maximumLineByteCount else {
				throw invalidOutputError(operation: operation)
			}

			let line = buffer
			buffer.removeAll(keepingCapacity: false)

			if let event = try event(from: line, operation: operation) {
				events.append(event)
			}
		}

		guard let terminalEvent else {
			throw invalidOutputError(operation: operation)
		}
		events.append(terminalEvent)

		return events
	}

	// JSONL 한 줄을 검증하고 정규화된 진행 사건으로 변환합니다.
	private mutating func event(
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

		guard
			event.event.hasPrefix("\(descriptor.namespace)."),
			event.operation == descriptor.operation
		else {
			throw invalidOutputError(operation: operation)
		}

		let kind = try kind(
			for: event.event,
			status: event.status,
			operation: operation
		)
		let normalizedEvent = XcodeBuildMCPEvent(
			operation: operation,
			kind: kind,
			message: normalizedStatus(event.status)
		)
		if kind == .completed || kind == .failed {
			terminalEvent = normalizedEvent
			return nil
		}

		return normalizedEvent
	}

	// 허용된 summary status만 외부 사건 메시지로 보존합니다.
	private func normalizedStatus(_ status: String?) -> String? {
		switch status {
		case "FAILED", "SUCCEEDED":
			return status
		default:
			return nil
		}
	}

	// XcodeBuildMCP 사건 이름을 공통 진행 단계로 변환합니다.
	private func kind(
		for name: String,
		status: String?,
		operation: XcodeBuildMCPOperation
	) throws -> XcodeBuildMCPEvent.Kind {
		guard let component = name.split(separator: ".").last else {
			return .progress
		}

		if component == "invocation" {
			return .started
		}
		if component.hasSuffix("summary") {
			switch status {
			case "FAILED":
				return .failed
			case "SUCCEEDED":
				return .completed
			default:
				throw invalidOutputError(operation: operation)
			}
		}

		return .progress
	}

	// 원본 출력 내용을 포함하지 않는 구조화된 출력 오류를 생성합니다.
	private func invalidOutputError(operation: XcodeBuildMCPOperation) -> RunError {
		.init(
			kind: .adapter,
			code: .init(rawValue: "adapter.xcodebuildmcp.output.invalid"),
			context: .init(command: operation.rawValue)
		)
	}

	// JSONL 한 줄에서 정규화에 필요한 필드만 해석합니다.
	private struct Event: Decodable {
		let event: String
		let operation: String
		let status: String?
	}
}

// JSONL 공백 문자를 판별합니다.
private extension UInt8 {
	// JSONL 레코드에서 무시 가능한 공백인지를 반환합니다.
	var isJSONLineWhitespace: Bool {
		self == 0x09 || self == 0x0D || self == 0x20
	}
}
