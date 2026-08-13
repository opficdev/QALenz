//
//  CLIApplicationTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCLI

@Suite
struct CLIApplicationTests {
	@Test
	func 도움말_요청은_standardOutput만_사용하고_success로_종료한다() async throws {
		let result = await CLIApplication.execute(arguments: ["--help"])

		#expect(result.exitStatus == .success)
		#expect(try #require(result.standardOutput).contains("qalenz"))
		#expect(result.standardError == nil)
	}

	@Test
	func 알_수_없는_명령은_standardError에_text_사용_오류를_쓰고_usageError로_종료한다() async throws {
		let result = await CLIApplication.execute(arguments: ["unknown"])

		#expect(result.exitStatus == .usageError)
		#expect(try #require(result.standardError).contains("Usage:"))
		#expect(result.standardOutput == nil)
	}

	@Test
	func JSON_출력을_요청한_잘못된_옵션은_구조화된_CLIUsageError를_standardError에_쓴다() async throws {
		let result = await CLIApplication.execute(
			arguments: ["--output", "json", "--unknown"]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.result.status == .errored)
		#expect(error.error.kind == .configuration)
		#expect(error.error.code.rawValue == "cli.usage.invalid")
		#expect(!error.message.isEmpty)
		#expect(!error.usage.isEmpty)
	}

	@Test
	func JSON_출력을_요청한_알_수_없는_명령은_명령을_포함한_CLIUsageError를_쓴다() async throws {
		let result = await CLIApplication.execute(
			arguments: ["--output", "json", "unknown"]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.error.code.rawValue == "cli.usage.invalid")
		#expect(error.message.contains("unknown"))
	}

	@Test
	func CLIUsageError의_RunResult가_errored가_아니면_디코딩을_거부한다() {
		let json = """
		{"message":"Invalid usage","result":{"status":"passed"},"usage":"qalenz"}
		"""

		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(CLIUsageError.self, from: Data(json.utf8))
		}
	}

	@Test
	func 같은_CLIUsageError의_text와_JSON_출력은_message_usage_exitStatus가_같다() async throws {
		let text = await CLIApplication.execute(arguments: ["--unknown"])
		let json = await CLIApplication.execute(
			arguments: ["--output", "json", "--unknown"]
		)
		let data = try #require(json.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)
		let message = try #require(text.standardError)

		#expect(message.contains(error.message))
		#expect(message.contains(error.usage))
		#expect(text.exitStatus == json.exitStatus)
	}
}
