//
//  ExecutionPlanBuilderTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ExecutionPlanBuilder의 target, step, test data 계획 구성을 검증합니다.
@Suite
struct ExecutionPlanBuilderTests {
	// target과 step 순서, 예상 부작용, test data 요구를 실행 없이 계획으로 보존하는지 검증합니다.
	@Test
	func target과_step과_testDataRequirements를_실행_없이_계획한다() throws {
		let outputDirectoryURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let plan = try ExecutionPlanBuilder().build(
			scenario: scenario(),
			configuration: configuration(outputDirectoryURL: outputDirectoryURL)
		)

		#expect(!FileManager.default.fileExists(atPath: outputDirectoryURL.path))
		#expect(plan.scenarioID == "todo-completion")
		#expect(plan.testDataRequirements == [.init(
			operation: .create,
			resource: "todo:incomplete"
		)])
		#expect(plan.targets.map(\.target.device) == [
			"iPhone 17", "iPhone 17", "iPhone 16", "iPhone 16"
		])
		#expect(plan.targets.map(\.target.appearance) == [
			"dark", "light", "dark", "light"
		])
		#expect(plan.targets.allSatisfy { target in
			target.outputDirectoryPath.hasPrefix(outputDirectoryURL.path)
		})
		#expect(plan.targets.first?.steps.map(\.id) == ["launch", "tap-profile"])
		#expect(plan.targets.first?.steps.map(\.sideEffects) == [
			[.appLaunch, .simulatorUse],
			[.simulatorUse]
		])
		#expect(plan.targets.first?.assertions == ["tap-profile"])
		#expect(plan.targets.first?.evidence == ["launch"])
	}

	// 실행 계획에 사용할 scenario를 반환합니다.
	private func scenario() -> Scenario {
		Scenario(
			schemaVersion: 1,
			id: "todo-completion",
			name: "Todo completion",
			profile: "default",
			matrix: .object([
				"devices": .array([.string("iPhone 17"), .string("iPhone 16")]),
				"appearances": .array([.string("dark"), .string("light")])
			]),
			steps: [
				.init(id: "launch", action: .buildAndRun),
				.init(
					id: "tap-profile",
					action: .tap,
					selector: .init(identifier: "profile-button")
				)
			],
			assertions: [.init(afterStepID: "tap-profile")],
			evidence: [.init(afterStepID: "launch")],
			testDataRequirements: [
				.init(operation: .create, resource: "todo:incomplete")
			]
		)
	}

	// 실행 계획에 사용할 정규화된 config를 반환합니다.
	private func configuration(outputDirectoryURL: URL) -> QALenzConfiguration {
		.init(
			schemaVersion: 1,
			projectRootURL: URL(fileURLWithPath: "/tmp/Project", isDirectory: true),
			xcodeBuildMCPProfile: "default",
			scenariosDirectoryURL: URL(fileURLWithPath: "/tmp/Project/scenarios", isDirectory: true),
			outputDirectoryURL: outputDirectoryURL,
			targetDefaults: .init(
				devices: ["iPhone 16"],
				operatingSystems: ["iOS 26.0"],
				appearances: ["light"]
			),
			targetPolicy: .init(maximumTargetCount: 12)
		)
	}
}
