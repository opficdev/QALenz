//
//  XcodeBuildMCPResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct XcodeBuildMCPResult: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let result: RunResult

	package init(
		operation: XcodeBuildMCPOperation,
		result: RunResult
	) {
		self.operation = operation
		self.result = result
	}
}
