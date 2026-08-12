//
//  RunResultTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore

@Suite
struct RunResultTests {
	@Test
	func 각_RunResult_값은_서로_다른_status를_노출한다() {
		let error = RunError(
			kind: .adapter,
			code: .init(rawValue: "adapter.unavailable")
		)

		#expect(RunResult.passed.status == .passed)
		#expect(RunResult.failed.status == .failed)
		#expect(RunResult.errored(error).status == .errored)
	}

	@Test(
		arguments: [
			RunResult.passed,
			.failed,
			.errored(
				RunError(
					kind: .execution,
					code: .init(rawValue: "execution.timeout"),
					context: .init(command: "run", step: "launch")
				)
			)
		]
	)
	func 모든_RunResult_값은_JSON_왕복_변환_후에도_같다(_ result: RunResult) throws {
		let data = try JSONEncoder().encode(result)
		let decoded = try JSONDecoder().decode(RunResult.self, from: data)

		#expect(decoded == result)
	}

	@Test
	func RunResult_값을_JSON_형식으로_인코딩하면_errored_상태에만_error_필드가_포함된다() throws {
		let passed = try object(for: .passed)
		let failed = try object(for: .failed)
		let errored = try object(
			for: .errored(
				RunError(
					kind: .verdict,
					code: .init(rawValue: "verdict.evidence.missing")
				)
			)
		)

		#expect(Set(passed.keys) == ["status"])
		#expect(passed["status"] as? String == "passed")
		#expect(Set(failed.keys) == ["status"])
		#expect(failed["status"] as? String == "failed")
		#expect(Set(errored.keys) == ["status", "error"])
		#expect(errored["status"] as? String == "errored")
	}

	@Test(
		arguments: [
			"""
			{"status":"passed","error":{"kind":"adapter","code":"adapter.unavailable","context":{}}}
			""",
			"""
			{"status":"failed","error":{"kind":"adapter","code":"adapter.unavailable","context":{}}}
			""",
			"""
			{"status":"errored"}
			""",
			"""
			{"status":"unknown"}
			"""
		]
	)
	func status_error_조합이_유효하지_않으면_RunResult_디코딩을_거부한다(_ json: String) {
		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(RunResult.self, from: Data(json.utf8))
		}
	}

	@Test
	func RunResult_공유_타입은_Codable_Sendable_Equatable_계약을_충족한다() {
		requireContract(RunResult.self)
		requireContract(RunResult.Status.self)
	}

	private func object(for result: RunResult) throws -> [String: Any] {
		let data = try JSONEncoder().encode(result)

		return try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)
	}

	private func requireContract<T: Codable & Sendable & Equatable>(_: T.Type) {}
}
