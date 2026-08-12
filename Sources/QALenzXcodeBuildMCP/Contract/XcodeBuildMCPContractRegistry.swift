//
//  XcodeBuildMCPContractRegistry.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import QALenzCore

// 지원하는 XcodeBuildMCP version의 command와 output 계약을 보관합니다.
struct XcodeBuildMCPContractRegistry: Sendable {
	let commandDescriptors: [
		XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor
	]
	let outputContracts: [
		XcodeBuildMCPOperation: [String: XcodeBuildMCPOutputContract]
	]
	let eventContracts: [XcodeBuildMCPOperation: XcodeBuildMCPEventContract]

	// operation별 command와 JSON 및 JSONL 계약으로 registry를 구성합니다.
	init(
		commandDescriptors: [
			XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor
		],
		outputContracts: [
			XcodeBuildMCPOperation: [String: XcodeBuildMCPOutputContract]
		],
		eventContracts: [
			XcodeBuildMCPOperation: XcodeBuildMCPEventContract
		]
	) {
		self.commandDescriptors = commandDescriptors
		self.outputContracts = outputContracts
		self.eventContracts = eventContracts
	}
}

extension XcodeBuildMCPContractRegistry {
	// 현재 지원하는 XcodeBuildMCP CLI contract를 반환합니다.
	static var current: Self {
		return .init(
			commandDescriptors: currentCommandDescriptors,
			outputContracts: currentOutputContracts,
			eventContracts: currentEventContracts
		)
	}

	private static let discoverSimulators = XcodeBuildMCPOperation(
		rawValue: "discover.simulators"
	)
	private static let buildSimulator = XcodeBuildMCPOperation(
		rawValue: "build.simulator"
	)

	private static var currentCommandDescriptors: [
		XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor
	] {
		[
			discoverSimulators: .init(
				workflow: "simulator",
				tool: "list"
			),
			buildSimulator: .init(
				workflow: "simulator",
				tool: "build",
				argumentFlags: [
					"configuration": "--configuration",
					"project.root": "--project-path",
					"scheme": "--scheme",
					"simulator.id": "--simulator-id",
					"simulator.name": "--simulator-name",
					"workspace.root": "--workspace-path"
				]
			)
		]
	}

	private static var currentOutputContracts: [
		XcodeBuildMCPOperation: [String: XcodeBuildMCPOutputContract]
	] {
		let simulator = XcodeBuildMCPPayloadSchema.object(
			fields: [
				"name": .scalar,
				"simulatorId": .scalar,
				"state": .scalar,
				"isAvailable": .scalar,
				"runtime": .scalar
			],
			requiredFields: [
				"name", "simulatorId", "state", "isAvailable", "runtime"
			]
		)
		let summary = XcodeBuildMCPPayloadSchema.object(
			fields: [
				"status": .scalar,
				"durationMs": .scalar,
				"target": .scalar
			],
			requiredFields: ["status"]
		)

		return [
			discoverSimulators: [
				"xcodebuildmcp.output.simulator-list": .init(
					versions: ["2"],
					payload: .init(
						isRequired: true,
						schema: .object(
							fields: ["simulators": .array(element: simulator)],
							requiredFields: ["simulators"]
						)
					)
				)
			],
			buildSimulator: [
				"xcodebuildmcp.output.build-result": .init(
					versions: ["2", "3"],
					payload: .init(
						isRequired: true,
						schema: .object(
							fields: ["summary": summary],
							requiredFields: ["summary"]
						)
					),
					result: .summaryStatus
				)
			]
		]
	}

	private static var currentEventContracts: [
		XcodeBuildMCPOperation: XcodeBuildMCPEventContract
	] {
		[
			buildSimulator: .init(
				namespace: "build-result",
				operation: "BUILD"
			)
		]
	}
}

// JSONL event가 속해야 하는 namespace와 tool operation을 보관합니다.
struct XcodeBuildMCPEventContract: Sendable, Equatable {
	let namespace: String
	let operation: String
}
