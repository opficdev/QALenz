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
	func 통과_결과가_성공_종료_상태로_변환된다() {
		#expect(CLIExitStatus(result: .passed).rawValue == 0)
	}

	@Test
	func 검증_실패_결과가_검증_실패_종료_상태로_변환된다() {
		#expect(CLIExitStatus(result: .failed).rawValue == 1)
	}

	@Test
	func 실행_오류_결과가_실행_오류_종료_상태로_변환된다() {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.test")
		)

		#expect(CLIExitStatus(result: .errored(error)).rawValue == 2)
	}

	@Test
	func 잘못된_사용법의_종료_상태는_64이다() {
		#expect(CLIExitStatus.usageError.rawValue == 64)
	}
}
