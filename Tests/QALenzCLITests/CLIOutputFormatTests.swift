//
//  CLIOutputFormatTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Testing
@testable import QALenzCLI

@Suite
struct CLIOutputFormatTests {
	@Test(arguments: [
		["--output", "json"],
		["--output=json"],
		["unknown", "--output", "json"],
	])
	func detectsJSONBeforeParsingFailure(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .json)
	}

	@Test(arguments: [
		[],
		["--output", "text"],
		["--output", "xml"],
		["--", "--output", "json"],
	])
	func defaultsToTextWithoutValidJSONRequest(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .text)
	}
}
