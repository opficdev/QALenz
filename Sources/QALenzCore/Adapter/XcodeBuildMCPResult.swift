//
//  XcodeBuildMCPResult.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

// XcodeBuildMCP operation과 정규화된 QALenz 실행 결과를 연결합니다.
package struct XcodeBuildMCPResult: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let result: RunResult

	// operation과 공통 실행 결과로 adapter 결과를 구성합니다.
	package init(
		operation: XcodeBuildMCPOperation,
		result: RunResult
	) {
		self.operation = operation
		self.result = result
	}
}
