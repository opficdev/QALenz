//
//  XcodeBuildMCPV2.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// XcodeBuildMCP 2.x CLI 명령과 구조화된 출력 명세를 보관합니다.
enum XcodeBuildMCPV2 {
	// XcodeBuildMCP 2.x semantic version의 지원 여부를 반환합니다.
	static func supports(version: String) -> Bool {
		version.wholeMatch(of: /v?2\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?/) != nil
	}

	static let commandBuilder = CommandBuilder(descriptors: [
		XcodeBuildMCPOperation.discoverSimulators: .init(
			workflow: "simulator",
			tool: "list",
			argumentFlags: [:]
		),
		XcodeBuildMCPOperation.buildSimulator: .init(
			workflow: "simulator",
			tool: "build",
			argumentFlags: [
				"scheme.name": "--scheme",
				"project.path": "--project-path",
				"workspace.path": "--workspace-path",
				"simulator.id": "--simulator-id",
				"simulator.name": "--simulator-name",
				"configuration": "--configuration"
			]
		)
	])

	static let outputDecoder = XcodeBuildMCPOutputDecoder(outputDefinitions: [
		XcodeBuildMCPOperation.discoverSimulators: [
			"xcodebuildmcp.output.simulator-list": .init(
				versions: ["1", "2"],
				payload: .init(
					isRequired: true,
					schema: .object(
						fields: [
							"simulators": .array(element: .object(
								fields: [
									"name": .string,
									"simulatorId": .string,
									"state": .string,
									"isAvailable": .boolean,
									"runtime": .string
								],
								requiredFields: [
									"name",
									"simulatorId",
									"state",
									"isAvailable",
									"runtime"
								]
							))
						],
						requiredFields: ["simulators"]
					)
				)
			)
		],
		XcodeBuildMCPOperation.buildSimulator: [
			"xcodebuildmcp.output.build-result": .init(
				versions: ["1", "2", "3"],
				payload: .init(
					isRequired: true,
					schema: .object(
						fields: [
							"summary": .object(
								fields: ["status": .string],
								requiredFields: ["status"]
							)
						],
						requiredFields: ["summary"]
					)
				),
				result: .summaryStatus
			)
		]
	])

	static let eventDescriptors: [XcodeBuildMCPOperation: EventDescriptor] = [
		XcodeBuildMCPOperation.buildSimulator: .init(
			namespace: "build-result",
			operation: "BUILD"
		)
	]
}

// XcodeBuildMCP 2.x 명세가 지원하는 의미 기반 operation을 보관합니다.
private extension XcodeBuildMCPOperation {
	static let discoverSimulators = Self(rawValue: "discover.simulators")
	static let buildSimulator = Self(rawValue: "build.simulator")
}
