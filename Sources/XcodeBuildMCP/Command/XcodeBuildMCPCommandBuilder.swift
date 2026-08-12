//
//  XcodeBuildMCPCommandBuilder.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// 의미 기반 요청을 XcodeBuildMCP CLI argument로 변환합니다.
package struct XcodeBuildMCPCommandBuilder: Sendable {
	package let descriptors: [XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor]

	// operation별 command descriptor로 builder를 구성합니다.
	package init(
		descriptors: [XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor]
	) {
		self.descriptors = descriptors
	}

	// 요청과 출력 형식에 맞는 XcodeBuildMCP CLI argument를 생성합니다.
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

// operation에 대응하는 workflow, tool, flag 구성을 보관합니다.
package struct XcodeBuildMCPCommandDescriptor: Sendable, Equatable {
	package let workflow: String
	package let tool: String
	package let argumentFlags: [String: String]

	// workflow와 tool 및 의미 기반 argument flag로 descriptor를 구성합니다.
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

// XcodeBuildMCP CLI가 반환할 출력 형식을 구분합니다.
package enum XcodeBuildMCPOutputFormat: String, Sendable, Equatable {
	case json
	case jsonLines = "jsonl"
}
