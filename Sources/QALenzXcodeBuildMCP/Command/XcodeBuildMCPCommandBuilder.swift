//
//  XcodeBuildMCPCommandBuilder.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

package struct XcodeBuildMCPCommandBuilder: Sendable {
	package let descriptors: [XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor]

	package init(
		descriptors: [XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor]
	) {
		self.descriptors = descriptors
	}

	package func arguments(
		for request: XcodeBuildMCPRequest,
		output: XcodeBuildMCPOutputFormat
	) throws -> [String] {
		guard let descriptor = descriptors[request.operation] else {
			throw RunError(
				kind: .adapter,
				code: .init(
					rawValue: "adapter.xcodebuildmcp.command.unsupported"
				),
				context: .init(command: request.operation.rawValue)
			)
		}

		var arguments = [descriptor.workflow, descriptor.tool]

		for argument in request.arguments {
			guard let flag = descriptor.argumentFlags[argument.name] else {
				throw RunError(
					kind: .adapter,
					code: .init(
						rawValue: "adapter.xcodebuildmcp.argument.unsupported"
					),
					context: .init(command: request.operation.rawValue)
				)
			}
			arguments.append(contentsOf: [flag, argument.value])
		}

		arguments.append(contentsOf: ["--output", output.rawValue])

		return arguments
	}
}

package struct XcodeBuildMCPCommandDescriptor: Sendable, Equatable {
	package let workflow: String
	package let tool: String
	package let argumentFlags: [String: String]

	package init(
		workflow: String,
		tool: String,
		argumentFlags: [String: String] = [:]
	) {
		self.workflow = workflow
		self.tool = tool
		self.argumentFlags = argumentFlags
	}
}

package enum XcodeBuildMCPOutputFormat: String, Sendable, Equatable {
	case json
	case jsonLines = "jsonl"
}
