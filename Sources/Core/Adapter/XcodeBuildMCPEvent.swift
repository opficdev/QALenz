//
//  XcodeBuildMCPEvent.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// XcodeBuildMCP 실행 중 발생한 진행 상황을 QALenz 형식으로 표현합니다.
package struct XcodeBuildMCPEvent: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let kind: Kind
	package let message: String?

	// operation과 진행 단계 및 메시지로 사건을 구성합니다.
	package init(
		operation: XcodeBuildMCPOperation,
		kind: Kind,
		message: String? = nil
	) {
		self.operation = operation
		self.kind = kind
		self.message = message
	}
}

// 사건에 필요한 종류를 확장합니다.
extension XcodeBuildMCPEvent {
	// XcodeBuildMCP 실행의 시작, 진행, 완료 및 실패 단계를 구분합니다.
	package enum Kind: Sendable, Equatable {
		case started
		case progress
		case completed
		case failed
	}
}
