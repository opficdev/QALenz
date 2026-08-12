//
//  QALenzCLIApplicationTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCLI

@Suite
struct QALenzCLIApplicationTests {
	@Test
	func writesHelpToStandardOutput() throws {
		let result = QALenzCLIApplication.execute(arguments: ["--help"])

		#expect(result.exitStatus == .success)
		#expect(try #require(result.standardOutput).contains("qalenz"))
		#expect(result.standardError == nil)
	}

	@Test
	func writesTextUsageErrorToStandardError() throws {
		let result = QALenzCLIApplication.execute(arguments: ["unknown"])

		#expect(result.exitStatus == .usageError)
		#expect(try #require(result.standardError).contains("Usage:"))
		#expect(result.standardOutput == nil)
	}

	@Test
	func writesStructuredJSONUsageError() throws {
		let result = QALenzCLIApplication.execute(
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
	func writesStructuredJSONUsageErrorForUnknownCommand() throws {
		let result = QALenzCLIApplication.execute(
			arguments: ["--output", "json", "unknown"]
		)
		let data = try #require(result.standardError?.data(using: .utf8))
		let error = try JSONDecoder().decode(CLIUsageError.self, from: data)

		#expect(result.exitStatus == .usageError)
		#expect(error.error.code.rawValue == "cli.usage.invalid")
		#expect(error.message.contains("unknown"))
	}

	@Test
	func rejectsUsageErrorWithNonErroredResult() {
		let json = """
		{"message":"Invalid usage","result":{"status":"passed"},"usage":"qalenz"}
		"""

		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(CLIUsageError.self, from: Data(json.utf8))
		}
	}

	@Test
	func keepsTextAndJSONUsageMeaningEqual() throws {
		let text = QALenzCLIApplication.execute(arguments: ["--unknown"])
		let json = QALenzCLIApplication.execute(
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
