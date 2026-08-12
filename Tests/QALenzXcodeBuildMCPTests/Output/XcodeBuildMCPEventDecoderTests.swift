//
//  XcodeBuildMCPEventDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite
struct XcodeBuildMCPEventDecoderTests {
	private let operation = XcodeBuildMCPOperation(
		rawValue: "build.simulator"
	)

	@Test
	func JSONL_이벤트가_공통_진행_단계와_메시지로_변환된다() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let jsonLines = """
		{"event":"build-result.invocation","operation":"BUILD"}
		{"event":"build-result.build-stage","message":"Compiling"}
		{"event":"build-result.build-summary","status":"SUCCEEDED"}

		"""

		let events = try decoder.decode(
			Data(jsonLines.utf8),
			operation: operation
		)

		#expect(events.map(\.kind) == [.started, .progress, .completed])
		#expect(events.map(\.message) == [nil, nil, "SUCCEEDED"])
	}

	@Test
	func 나뉜_JSONL_이벤트가_줄바꿈_전까지_버퍼에_남는다() throws {
		var decoder = XcodeBuildMCPEventDecoder()

		let first = try decoder.decode(
			Data(#"{"event":"build-result.build-stage","message":"Com"#.utf8),
			operation: operation
		)
		let second = try decoder.decode(
			Data("piling\"}\n".utf8),
			operation: operation
		)

		#expect(first.isEmpty)
		#expect(second.map(\.kind) == [.progress])
	}

	@Test
	func 줄바꿈_없는_마지막_이벤트가_마무리_시점에_처리된다() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let json = #"{"event":"build-result.build-summary","status":"FAILED"}"#

		let pending = try decoder.decode(
			Data(json.utf8),
			operation: operation
		)
		let final = try decoder.finish(operation: operation)

		#expect(pending.isEmpty)
		#expect(final.map(\.kind) == [.failed])
		#expect(final.map(\.message) == ["FAILED"])
	}

	@Test
	func 실패_summary가_실패_사건으로_변환된다() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let json = """
		{"event":"build-result.build-summary","status":"FAILED"}

		"""

		let events = try decoder.decode(Data(json.utf8), operation: operation)

		#expect(events.map(\.kind) == [.failed])
	}

	@Test
	func 잘못된_이벤트의_원본_내용이_오류에_복사되지_않는다() throws {
		var decoder = XcodeBuildMCPEventDecoder()

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

	@Test
	func 원본_message와_허용되지_않은_status가_사건에_노출되지_않는다() throws {
		var decoder = XcodeBuildMCPEventDecoder()
		let jsonLines = """
		{"event":"build-result.build-stage","message":"secret-token-value"}
		{"event":"build-result.build-stage","status":"secret-status-value"}

		"""

		let events = try decoder.decode(
			Data(jsonLines.utf8),
			operation: operation
		)

		#expect(events.map(\.message) == [nil, nil])
	}

	@Test
	func 최대_크기를_초과한_JSONL_한_줄이_거부된다() {
		var decoder = XcodeBuildMCPEventDecoder(maximumLineByteCount: 32)

		do {
			_ = try decoder.decode(
				Data(repeating: 0x61, count: 33),
				operation: operation
			)
			Issue.record("크기를 초과한 JSONL 입력이 거부되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
		} catch {
			Issue.record("구조화되지 않은 오류 반환")
		}
	}

	@Test
	func 최대_크기_이하의_JSONL_여러_줄이_모두_처리된다() throws {
		let line = #"{"event":"build-result.invocation"}"#
		var decoder = XcodeBuildMCPEventDecoder(
			maximumLineByteCount: line.utf8.count
		)
		let jsonLines = "\(line)\n\(line)\n"

		let events = try decoder.decode(
			Data(jsonLines.utf8),
			operation: operation
		)

		#expect(events.map(\.kind) == [.started, .started])
	}

	@Test
	func 지원하지_않는_summary_status가_거부된다() {
		var decoder = XcodeBuildMCPEventDecoder()
		let json = """
		{"event":"build-result.build-summary","status":"UNKNOWN"}

		"""

		do {
			_ = try decoder.decode(Data(json.utf8), operation: operation)
			Issue.record("지원하지 않는 summary status가 거부되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.output.invalid")
		} catch {
			Issue.record("구조화되지 않은 오류 반환")
		}
	}
}
