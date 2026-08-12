//
//  RunErrorTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore

@Suite
struct RunErrorTests {
	@Test
	func RunError_값은_JSON_왕복_변환_후에도_구조화된_값이_같다() throws {
		let error = RunError(
			kind: .adapter,
			code: .init(rawValue: "adapter.schema.invalid"),
			context: .init(
				command: "run",
				target: "DevLog",
				step: "launch",
				assertion: "header.visible"
			)
		)

		let data = try JSONEncoder().encode(error)
		let decoded = try JSONDecoder().decode(RunError.self, from: data)

		#expect(decoded == error)
	}

	@Test
	func RunError_값을_JSON_형식으로_인코딩하면_구조화된_필드만_포함한다() throws {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.timeout"),
			context: .init(command: "run")
		)

		let data = try JSONEncoder().encode(error)
		let object = try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)
		let context = try #require(object["context"] as? [String: Any])

		#expect(Set(object.keys) == ["kind", "code", "context"])
		#expect(object["code"] as? String == "execution.timeout")
		#expect(Set(context.keys) == ["command"])
	}

	@Test(
		arguments: [
			RunError.Kind.configuration,
			.adapter,
			.execution,
			.evidence,
			.verdict,
			.report
		]
	)
	func 모든_RunError_종류는_JSON_왕복_변환_후에도_같다(_ kind: RunError.Kind) throws {
		let error = RunError(
			kind: kind,
			code: .init(rawValue: "test.code"),
			context: .init()
		)

		let data = try JSONEncoder().encode(error)
		let decoded = try JSONDecoder().decode(RunError.self, from: data)

		#expect(decoded == error)
	}

	@Test
	func RunError_공유_타입은_Codable_Sendable_Equatable_계약을_충족한다() {
		requireContract(RunError.self)
		requireContract(RunError.Kind.self)
		requireContract(RunError.Code.self)
		requireContract(RunError.Context.self)
	}

	private func requireContract<T: Codable & Sendable & Equatable>(_: T.Type) {}
}
