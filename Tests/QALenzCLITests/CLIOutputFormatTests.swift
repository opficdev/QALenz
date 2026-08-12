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
	func 명령행_해석에_실패하기_전_JSON_출력_요청을_감지한다(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .json)
	}

	@Test(arguments: [
		[],
		["--output", "text"],
		["--output", "xml"],
		["--", "--output", "json"]
	])
	func 유효한_JSON_출력_요청이_없으면_text를_기본_출력으로_선택한다(_ arguments: [String]) {
		#expect(CLIOutputFormat.requested(in: arguments) == .text)
	}
}
