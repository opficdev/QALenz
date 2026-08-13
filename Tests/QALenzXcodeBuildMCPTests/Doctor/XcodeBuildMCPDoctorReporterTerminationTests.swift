//
//  XcodeBuildMCPDoctorReporterTerminationTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCP doctor reporter의 version 종료 상태 변환을 검증합니다.
@Suite
struct XcodeBuildMCPDoctorTerminationTests {
	// version command의 일반 종료 실패를 adapter 실행 오류로 반환하는지 검증합니다.
	@Test(arguments: [Int32(1), 126])
	func version_command의_일반_종료_실패를_adapter_실행_오류로_반환한다(
		status: Int32
	) async {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(
				standardOutput: Data("secret-token-value".utf8),
				terminationStatus: status
			)
		])
		let reporter = makeReporter(processRunner: runner)

		do {
			_ = try await reporter.diagnoseXcodeBuildMCP()
			Issue.record("RunError를 반환해야 합니다.")
		} catch let error as RunError {
			#expect(error.kind == .adapter)
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
			#expect(!String(describing: error).contains("secret-token-value"))
		} catch {
			Issue.record("RunError 대신 다른 오류를 반환했습니다.")
		}
	}
}
