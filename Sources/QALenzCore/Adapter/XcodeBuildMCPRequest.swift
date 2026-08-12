//
//  XcodeBuildMCPRequest.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct XcodeBuildMCPRequest: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let arguments: [XcodeBuildMCPArgument]

	package init(
		operation: XcodeBuildMCPOperation,
		arguments: [XcodeBuildMCPArgument] = []
	) {
		self.operation = operation
		self.arguments = arguments
	}
}

package struct XcodeBuildMCPOperation: RawRepresentable, Sendable, Equatable, Hashable {
	package let rawValue: String

	package init(rawValue: String) {
		self.rawValue = rawValue
	}
}

package struct XcodeBuildMCPArgument: Sendable, Equatable {
	package let name: String
	package let value: String

	package init(name: String, value: String) {
		self.name = name
		self.value = value
	}
}
