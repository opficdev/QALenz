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
		XcodeBuildMCPOperation.discoverProjects: .init(
			workflow: "project-discovery",
			tool: "discover-projects",
			argumentFlags: [
				"workspace.root": "--workspace-root"
			],
			requiredArgumentGroups: [["workspace.root"]]
		),
		XcodeBuildMCPOperation.discoverSchemes: .init(
			workflow: "project-discovery",
			tool: "list-schemes",
			argumentFlags: [
				"project.path": "--project-path",
				"workspace.path": "--workspace-path"
			],
			requiredArgumentGroups: [["project.path", "workspace.path"]],
			exclusiveArgumentGroups: [["project.path", "workspace.path"]]
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
		),
		XcodeBuildMCPOperation.buildAndRunSimulator: .init(
			workflow: "simulator",
			tool: "build-and-run",
			argumentFlags: [
				"profile": "--profile",
				"simulator.name": "--simulator-name"
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
		XcodeBuildMCPOperation.discoverProjects: [
			"xcodebuildmcp.output.project-list": .init(
				versions: ["2"],
				payload: .init(
					isRequired: true,
					schema: .object(
						fields: [
							"projects": .array(element: .object(
								fields: ["path": .string],
								requiredFields: ["path"]
							)),
							"workspaces": .array(element: .object(
								fields: ["path": .string],
								requiredFields: ["path"]
							))
						],
						requiredFields: ["projects", "workspaces"]
					)
				)
			)
		],
		XcodeBuildMCPOperation.discoverSchemes: [
			"xcodebuildmcp.output.scheme-list": .init(
				versions: ["2"],
				payload: .init(
					isRequired: true,
					schema: .object(
						fields: ["schemes": .array(element: .string)],
						requiredFields: ["schemes"]
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
		],
		XcodeBuildMCPOperation.buildAndRunSimulator: [
			"xcodebuildmcp.output.build-run-result": .init(
				versions: ["2"],
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
		),
		XcodeBuildMCPOperation.buildAndRunSimulator: .init(
			namespace: "build-run-result",
			operation: "BUILD"
		)
	]
}
