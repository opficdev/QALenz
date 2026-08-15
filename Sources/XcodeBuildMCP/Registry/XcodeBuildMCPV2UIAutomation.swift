//
//  XcodeBuildMCPV2UIAutomation.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import QALenzCore

// XcodeBuildMCP 2.x UI automation CLI와 구조화된 출력 명세를 보관합니다.
enum XcodeBuildMCPV2UIAutomation {
	static let commandDescriptors: [XcodeBuildMCPOperation: CommandDescriptor] = [
		.snapshotUI: .init(
			workflow: "ui-automation",
			tool: "snapshot-ui",
			argumentFlags: ["profile": "--profile"]
		),
		.waitForUI: .init(
			workflow: "ui-automation",
			tool: "wait-for-ui",
			argumentFlags: [
				"profile": "--profile",
				"predicate": "--predicate",
				"timeout.milliseconds": "--timeout-ms",
				"selector.identifier": "--identifier",
				"selector.label": "--label",
				"selector.role": "--role",
				"selector.value": "--value"
			]
		),
		.tapUI: .init(
			workflow: "ui-automation",
			tool: "tap",
			argumentFlags: [
				"profile": "--profile",
				"element.reference": "--element-ref"
			]
		),
		.longPressUI: .init(
			workflow: "ui-automation",
			tool: "long-press",
			argumentFlags: [
				"profile": "--profile",
				"element.reference": "--element-ref",
				"duration.seconds": "--duration"
			]
		),
		.swipeUI: .init(
			workflow: "ui-automation",
			tool: "swipe",
			argumentFlags: [
				"profile": "--profile",
				"element.reference": "--within-element-ref",
				"direction": "--direction",
				"duration.seconds": "--duration",
				"distance": "--distance"
			]
		),
		.typeTextUI: .init(
			workflow: "ui-automation",
			tool: "type-text",
			argumentFlags: [
				"profile": "--profile",
				"element.reference": "--element-ref",
				"text": "--text",
				"replace.existing": "--replace-existing"
			]
		)
	]

	static let outputDefinitions: [XcodeBuildMCPOperation: [String: OutputDefinition]] = [
		.snapshotUI: captureOutputDefinitions,
		.waitForUI: captureOutputDefinitions,
		.tapUI: uiActionOutputDefinitions,
		.longPressUI: uiActionOutputDefinitions,
		.swipeUI: uiActionOutputDefinitions,
		.typeTextUI: uiActionOutputDefinitions
	]

	private static let captureOutputDefinitions: [String: OutputDefinition] = [
		"xcodebuildmcp.output.capture-result": .init(
			versions: ["2"],
			payload: .init(
				isRequired: true,
				schema: .object(
					fields: [
						"capture": runtimeSnapshotSchema,
						"uiError": errorSchema,
						"waitMatch": .object(
							fields: [
								"matches": .array(element: .object(
									fields: ["ref": .string],
									requiredFields: ["ref"]
								))
							],
							requiredFields: ["matches"]
						)
					],
					requiredFields: []
				)
			)
		)
	]

	private static let uiActionOutputDefinitions: [String: OutputDefinition] = [
		"xcodebuildmcp.output.ui-action-result": .init(
			versions: ["2"],
			payload: .init(
				isRequired: true,
				schema: .object(
					fields: [
						"capture": runtimeSnapshotSchema,
						"uiError": errorSchema
					],
					requiredFields: []
				)
			)
		)
	]

	private static let runtimeSnapshotSchema = PayloadSchema.object(
		fields: [
			"type": .string,
			"screenHash": .string,
			"seq": .scalar
		],
		requiredFields: ["type", "screenHash", "seq"]
	)

	private static let errorSchema = PayloadSchema.object(
		fields: ["code": .string],
		requiredFields: ["code"]
	)
}
