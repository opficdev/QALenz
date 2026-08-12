//
//  CLIExitStatus.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// CLI 프로세스의 종료 상태를 나타냅니다.
package struct CLIExitStatus: RawRepresentable, Sendable, Equatable {
	package let rawValue: Int32

	// 원시 종료 상태 값으로 초기화합니다.
	package init(rawValue: Int32) {
		self.rawValue = rawValue
	}

	// 실행 결과에 맞는 종료 상태로 초기화합니다.
	package init(result: RunResult) {
		switch result {
		case .passed:
			self = .success
		case .failed:
			self = .verificationFailure
		case .errored:
			self = .executionError
		}
	}

	package static let success = Self(rawValue: 0)
	package static let verificationFailure = Self(rawValue: 1)
	package static let executionError = Self(rawValue: 2)
	package static let usageError = Self(rawValue: 64)
}
