//
//  CommandBuilder.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// 의미 기반 요청을 XcodeBuildMCP CLI argument로 변환합니다.
package struct CommandBuilder: Sendable {
	package let descriptors: [XcodeBuildMCPOperation: CommandDescriptor]

	// operation별 command descriptor로 builder를 구성합니다.
	package init(descriptors: [XcodeBuildMCPOperation: CommandDescriptor]) {
		self.descriptors = descriptors
	}

	// 요청과 출력 형식에 맞는 XcodeBuildMCP CLI argument를 생성합니다.
	package func arguments(
		for request: XcodeBuildMCPRequest,
		output: CommandOutputFormat
	) throws -> [String] {
		guard let descriptor = descriptors[request.operation] else {
			throw RunError(
				kind: .adapter,
				code: .init(rawValue: "adapter.xcodebuildmcp.command.unsupported"),
				context: .init(command: request.operation.rawValue)
			)
		}

		let requestedArgumentNames = Set(request.arguments.map(\.name))
		guard descriptor.requiredArgumentGroups.allSatisfy({
			!requestedArgumentNames.isDisjoint(with: $0)
		}), descriptor.exclusiveArgumentGroups.allSatisfy({
			requestedArgumentNames.intersection($0).count <= 1
		}) else {
			throw RunError(
				kind: .adapter,
				code: .init(rawValue: "adapter.xcodebuildmcp.argument.unsupported"),
				context: .init(command: request.operation.rawValue)
			)
		}

		var arguments = [descriptor.workflow, descriptor.tool]

		for argument in request.arguments {
			guard let flag = descriptor.argumentFlags[argument.name] else {
				throw RunError(
					kind: .adapter,
					code: .init(rawValue: "adapter.xcodebuildmcp.argument.unsupported"),
					context: .init(command: request.operation.rawValue)
				)
			}
			arguments.append(contentsOf: [flag, argument.value])
		}

		arguments.append(contentsOf: ["--output", output.rawValue])

		return arguments
	}
}
