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
	let supportedSchemaVersions: [
		XcodeBuildMCPOperation: [String: Set<String>]
	]
	let eventContracts: [XcodeBuildMCPOperation: XcodeBuildMCPEventContract]

	// operation별 command와 JSON 및 JSONL 계약으로 registry를 구성합니다.
	init(
		commandDescriptors: [
			XcodeBuildMCPOperation: XcodeBuildMCPCommandDescriptor
		],
		supportedSchemaVersions: [
			XcodeBuildMCPOperation: [String: Set<String>]
		],
		eventContracts: [
			XcodeBuildMCPOperation: XcodeBuildMCPEventContract
		]
	) {
		self.commandDescriptors = commandDescriptors
		self.supportedSchemaVersions = supportedSchemaVersions
		self.eventContracts = eventContracts
	}
}

extension XcodeBuildMCPContractRegistry {
	// 현재 지원하는 XcodeBuildMCP CLI contract를 반환합니다.
	static var current: Self {
		let discoverSimulators = XcodeBuildMCPOperation(
			rawValue: "discover.simulators"
		)
		let buildSimulator = XcodeBuildMCPOperation(
			rawValue: "build.simulator"
		)

		return .init(
			commandDescriptors: [
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
			],
			supportedSchemaVersions: [
				discoverSimulators: [
					"xcodebuildmcp.output.simulator-list": ["2"]
				],
				buildSimulator: [
					"xcodebuildmcp.output.build-result": ["2", "3"]
				]
			],
			eventContracts: [
				buildSimulator: .init(
						namespace: "build-result",
						operation: "BUILD"
					)
				]
		)
	}
}

// JSONL event가 속해야 하는 namespace와 tool operation을 보관합니다.
struct XcodeBuildMCPEventContract: Sendable, Equatable {
	let namespace: String
	let operation: String
}
