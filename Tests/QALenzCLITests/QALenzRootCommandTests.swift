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
	func 도움말_요청이_성공_종료와_도움말을_제공한다() throws {
		let error = try #require(caughtError(for: ["--help"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error).contains("qalenz"))
	}

	@Test
	func 버전_요청이_성공_종료와_현재_버전을_제공한다() throws {
		let error = try #require(caughtError(for: ["--version"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error) == CLIVersion.current)
	}

	@Test
	func 공통_출력_형식을_파싱한다() throws {
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
