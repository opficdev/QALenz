//
//  CLIExitStatusTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Testing
@testable import QALenzCLI
@testable import QALenzCore

@Suite
struct CLIExitStatusTests {
	@Test
	func passed_RunResult의_CLIExitStatus_rawValue는_0이다() {
		#expect(CLIExitStatus(result: .passed).rawValue == 0)
	}

	@Test
	func failed_RunResult의_CLIExitStatus_rawValue는_1이다() {
		#expect(CLIExitStatus(result: .failed).rawValue == 1)
	}

	@Test
	func errored_RunResult의_CLIExitStatus_rawValue는_2이다() {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.test")
		)

		#expect(CLIExitStatus(result: .errored(error)).rawValue == 2)
	}

	@Test
	func usageError_CLIExitStatus의_rawValue는_64이다() {
		#expect(CLIExitStatus.usageError.rawValue == 64)
	}
}
