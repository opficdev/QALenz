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
	func exposesMutuallyExclusiveStatuses() {
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
			),
		]
	)
	func preservesEveryResultThroughJSONRoundTrip(_ result: RunResult) throws {
		let data = try JSONEncoder().encode(result)
		let decoded = try JSONDecoder().decode(RunResult.self, from: data)

		#expect(decoded == result)
	}

	@Test
	func encodesErrorOnlyForErroredResult() throws {
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
			""",
		]
	)
	func rejectsInvalidStatusAndErrorCombinations(_ json: String) {
		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(RunResult.self, from: Data(json.utf8))
		}
	}

	@Test
	func satisfiesSharedContractRequirements() {
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
