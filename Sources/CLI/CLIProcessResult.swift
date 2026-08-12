//
//  CLIProcessResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct CLIProcessResult: Sendable, Equatable {
	package let standardOutput: String?
	package let standardError: String?
	package let exitStatus: CLIExitStatus

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
