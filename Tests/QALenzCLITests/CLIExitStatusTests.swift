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
	func mapsPassedResultToSuccess() {
		#expect(CLIExitStatus(result: .passed).rawValue == 0)
	}

	@Test
	func mapsFailedResultToVerificationFailure() {
		#expect(CLIExitStatus(result: .failed).rawValue == 1)
	}

	@Test
	func mapsErroredResultToExecutionError() {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.test")
		)

		#expect(CLIExitStatus(result: .errored(error)).rawValue == 2)
	}

	@Test
	func exposesUsageErrorStatus() {
		#expect(CLIExitStatus.usageError.rawValue == 64)
	}
}
