//
//  XcodeBuildMCPEvent.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct XcodeBuildMCPEvent: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let kind: Kind
	package let message: String?

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

extension XcodeBuildMCPEvent {
	package enum Kind: Sendable, Equatable {
		case started
		case progress
		case completed
	}
}
