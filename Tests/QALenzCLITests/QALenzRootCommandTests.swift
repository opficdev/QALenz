//
//  QALenzRootCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser
import Testing
@testable import QALenzCLI

@Suite
struct QALenzRootCommandTests {
	@Test
	func 도움말_요청은_도움말을_포함하고_success로_종료한다() throws {
		let error = try #require(caughtError(for: ["--help"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error).contains("qalenz"))
	}

	@Test
	func 버전_요청은_CLIVersion_current를_반환하고_success로_종료한다() throws {
		let error = try #require(caughtError(for: ["--version"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error) == CLIVersion.current)
	}

	@Test
	func JSON_출력_옵션은_CLIOutputFormat_json으로_해석된다() throws {
		let command = try QALenzRootCommand.parse(["--output", "json"])

		#expect(command.options.output == .json)
	}

	private func caughtError(for arguments: [String]) -> (any Error)? {
		do {
			var command = try QALenzRootCommand.parseAsRoot(arguments)
			try command.run()

			return nil
		} catch {
			return error
		}
	}
}
