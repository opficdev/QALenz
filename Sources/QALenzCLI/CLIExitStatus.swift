//
//  CLIExitStatus.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

package struct CLIExitStatus: RawRepresentable, Sendable, Equatable {
	package let rawValue: Int32

	package init(rawValue: Int32) {
		self.rawValue = rawValue
	}

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
