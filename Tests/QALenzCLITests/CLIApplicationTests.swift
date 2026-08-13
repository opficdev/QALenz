//
//  CLIApplicationTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

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

	// doctor 하위 명령의 JSON 사용 오류가 하위 명령 usage를 보존하는지 검증합니다.
	@Test
	func doctor_JSON_사용_오류가_하위_명령_usage를_보존한다() async throws {
		let result = await CLIApplication.execute(
			arguments: ["doctor", "--unknown", "--output", "json"]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.usage == "qalenz doctor [--output <output>]")
		#expect(error.usage.contains("qalenz doctor"))
	}

	// doctor의 text 출력 옵션이 root JSON보다 사용 오류에서 우선하는지 검증합니다.
	@Test
	func doctor_text_출력_옵션이_사용_오류에서_루트_JSON보다_우선한다() async throws {
		let result = await CLIApplication.execute(
			arguments: [
				"--output", "json", "doctor", "--output", "text", "--unknown"
			]
		)
		let error = try #require(result.standardError)

		#expect(result.exitStatus == .usageError)
		#expect(error.contains("Unknown option '--unknown'"))
		#expect(result.standardOutput == nil)
		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(CLIUsageError.self, from: Data(error.utf8))
		}
	}

	// doctor의 JSON 출력 옵션이 root text보다 사용 오류에서 우선하는지 검증합니다.
	@Test
	func doctor_JSON_출력_옵션이_사용_오류에서_루트_text보다_우선한다() async throws {
		let result = await CLIApplication.execute(
			arguments: [
				"--output", "text", "doctor", "--output", "json", "--unknown"
			]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.usage == "qalenz doctor [--output <output>]")
		#expect(result.standardOutput == nil)
	}

	// 알 수 없는 루트 명령의 앞선 JSON 옵션을 사용 오류에 보존하는지 검증합니다.
	@Test
	func 알_수_없는_루트_명령의_앞선_JSON_옵션을_사용_오류에_보존한다() async throws {
		let result = await CLIApplication.execute(
			arguments: [
				"--output", "json", "unknown", "doctor", "--output", "text"
			]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.message.contains("unknown"))
		#expect(result.standardOutput == nil)
	}

	// 알 수 없는 루트 명령 뒤의 JSON 옵션을 사용 오류에 보존하는지 검증합니다.
	@Test
	func 알_수_없는_루트_명령_뒤의_JSON_옵션을_사용_오류에_보존한다() async throws {
		let result = await CLIApplication.execute(
			arguments: [
				"--output", "text", "unknown", "doctor", "--output", "json"
			]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.message.contains("unknown"))
		#expect(result.standardOutput == nil)
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

	// doctor text 출력이 실행 오류 종류와 코드를 보존하는지 검증합니다.
	@Test
	func doctor_text_출력이_실행_오류_종류와_코드를_보존한다() throws {
		let report = DoctorReport(
			diagnostics: [],
			error: .init(
				kind: .execution,
				code: .init(rawValue: "execution.timeout"),
				context: .init(command: "secret-command")
			)
		)

		let result = CLIApplication.result(for: report, format: .text)
		let output = try #require(result.standardOutput)

		#expect(result.exitStatus == .executionError)
		#expect(output.contains("[errored] [execution] execution.timeout"))
		#expect(!output.contains("secret-command"))
		#expect(result.standardError == nil)
	}
}
