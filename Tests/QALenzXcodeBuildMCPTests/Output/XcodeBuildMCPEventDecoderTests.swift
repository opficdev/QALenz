//
//  XcodeBuildMCPEventDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPEventDecoder의 JSONL 정규화를 검증합니다.
@Suite
struct XcodeBuildMCPEventDecoderTests {
	private let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
	private let descriptor = EventDescriptor(
		namespace: "fixture",
		operation: "FIXTURE"
	)

	// JSONL 사건이 공통 진행 단계와 허용된 상태로 변환되는지 검증합니다.
	@Test
	func JSONL_이벤트가_공통_진행_단계와_메시지로_변환된다() throws {
		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)
		let jsonLines = """
		{"event":"fixture.invocation","operation":"FIXTURE"}
		{"event":"fixture.progress","operation":"FIXTURE","message":"secret-token-value"}
		{"event":"fixture.summary","operation":"FIXTURE","status":"SUCCEEDED"}

		"""

		var events = try decoder.decode(Data(jsonLines.utf8), operation: operation)
		events += try decoder.finish(operation: operation)

		#expect(events.map(\.kind) == [.started, .progress, .completed])
		#expect(events.map(\.message) == [nil, nil, "SUCCEEDED"])
	}

	// 분할된 JSONL 사건이 줄바꿈 전까지 보류되는지 검증합니다.
	@Test
	func 나뉜_JSONL_이벤트가_줄바꿈_전까지_버퍼에_남는다() throws {
		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)

		let first = try decoder.decode(
			Data(#"{"event":"fixture.progress","operation":"FIXTURE"}"#.utf8),
			operation: operation
		)
		let second = try decoder.decode(Data("\n".utf8), operation: operation)

		#expect(first.isEmpty)
		#expect(second.map(\.kind) == [.progress])
	}

	// 줄바꿈 없는 마지막 summary가 실패 사건으로 처리되는지 검증합니다.
	@Test
	func 줄바꿈_없는_마지막_이벤트가_마무리_시점에_처리된다() throws {
		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)
		let json = #"{"event":"fixture.summary","operation":"FIXTURE","status":"FAILED"}"#

		let pending = try decoder.decode(Data(json.utf8), operation: operation)
		let final = try decoder.finish(operation: operation)

		#expect(pending.isEmpty)
		#expect(final.map(\.kind) == [.failed])
		#expect(final.map(\.message) == ["FAILED"])
	}

	// 잘못된 사건이 원본 내용을 복사하지 않는 구조화된 오류가 되는지 검증합니다.
	@Test
	func 잘못된_이벤트의_원본_내용이_오류에_복사되지_않는다() throws {
		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)

		do {
			_ = try decoder.decode(
				Data("secret-token-value\n".utf8),
				operation: operation
			)
			Issue.record("잘못된 이벤트 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
			#expect(!String(describing: error).contains("secret-token-value"))
		}
	}

	// 다른 namespace와 operation 사건이 거부되는지 검증합니다.
	@Test
	func 다른_operation의_JSONL_namespace가_거부된다() {
		var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)
		let json = """
		{"event":"other.summary","operation":"OTHER","status":"SUCCEEDED"}

		"""

		#expect(throws: RunError.self) {
			_ = try decoder.decode(Data(json.utf8), operation: operation)
		}
	}
}
