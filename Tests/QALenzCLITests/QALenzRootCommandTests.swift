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
	func providesHelpAsCleanExit() throws {
		let error = try #require(caughtError(for: ["--help"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error).contains("qalenz"))
	}

	@Test
	func providesCurrentVersionAsCleanExit() throws {
		let error = try #require(caughtError(for: ["--version"]))

		#expect(QALenzRootCommand.exitCode(for: error) == .success)
		#expect(QALenzRootCommand.fullMessage(for: error) == CLIVersion.current)
	}

	@Test
	func parsesSharedOutputFormat() throws {
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
