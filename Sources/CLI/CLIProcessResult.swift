//
//  CLIProcessResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

// CLI 프로세스의 출력과 종료 상태를 전달합니다.
package struct CLIProcessResult: Sendable, Equatable {
	package let standardOutput: String?
	package let standardError: String?
	package let exitStatus: CLIExitStatus

	// 출력과 종료 상태로 초기화합니다.
	package init(
		standardOutput: String?,
		standardError: String?,
		exitStatus: CLIExitStatus
	) {
		self.standardOutput = standardOutput
		self.standardError = standardError
		self.exitStatus = exitStatus
	}
}
