//
//  CommandDescriptor.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// operation에 대응하는 workflow, tool, flag 구성을 보관합니다.
package struct CommandDescriptor: Sendable, Equatable {
	package let workflow: String
	package let tool: String
	package let argumentFlags: [String: String]
	package let requiredArgumentGroups: [Set<String>]
	package let exclusiveArgumentGroups: [Set<String>]

	// workflow와 tool 및 의미 기반 argument flag로 descriptor를 구성합니다.
	package init(
		workflow: String,
		tool: String,
		argumentFlags: [String: String] = [:],
		requiredArgumentGroups: [Set<String>] = [],
		exclusiveArgumentGroups: [Set<String>] = []
	) {
		self.workflow = workflow
		self.tool = tool
		self.argumentFlags = argumentFlags
		self.requiredArgumentGroups = requiredArgumentGroups
		self.exclusiveArgumentGroups = exclusiveArgumentGroups
	}
}
