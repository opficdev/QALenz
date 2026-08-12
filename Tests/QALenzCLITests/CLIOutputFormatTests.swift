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
		["unknown", "--output", "json"]
	])
	func 파싱_실패_전에_JSON_출력_요청을_찾는다(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .json)
	}

	@Test(arguments: [
		[],
		["--output", "text"],
		["--output", "xml"],
		["--", "--output", "json"]
	])
	func 올바른_JSON_출력_요청이_없으면_텍스트_출력을_사용한다(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .text)
	}
}
