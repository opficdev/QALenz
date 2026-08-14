//
//  RunCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

// qalenz run dry-run 명령의 계획 출력과 실행 차단을 검증합니다.
@Suite
struct RunCommandTests {
	// dry-run이 현재 작업 경로의 고정 config 위치로 계획만 요청하는지 검증합니다.
	@Test
	func dryRun이_고정_config_위치로_계획만_요청한다() async throws {
		let loader = ExecutionPlanLoaderSpy(plan: plan())
		let command = try runCommand()
		let currentDirectoryURL = URL(fileURLWithPath: "/tmp/RunCurrent", isDirectory: true)

		let result = await command.execute(
			format: .text,
			loader: loader,
			currentDirectoryURL: currentDirectoryURL
		)

		#expect(result.exitStatus == .success)
		#expect(loader.configurationURLs() == [
			currentDirectoryURL
				.appendingPathComponent(".qalenz", isDirectory: true)
				.appendingPathComponent("config.json", isDirectory: false)
		])
		#expect(try #require(result.standardOutput).contains("testDataRequirements:"))
		#expect(try #require(result.standardOutput).contains("selector: -"))
		#expect(try #require(result.standardOutput).contains("evidence | launch"))
		#expect(result.standardError == nil)
	}

	// text와 JSON 출력이 동일한 실행 계획을 보존하는지 검증합니다.
	@Test
	func text와_JSON이_같은_실행_계획을_반환한다() async throws {
		let command = try runCommand()
		let text = await command.execute(
			format: .text,
			loader: ExecutionPlanLoaderSpy(plan: plan()),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			loader: ExecutionPlanLoaderSpy(plan: plan()),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))

		#expect(text.exitStatus == .success)
		#expect(json.exitStatus == text.exitStatus)
		#expect(try JSONDecoder().decode(ExecutionPlan.self, from: data) == plan())
		#expect(json.standardError == nil)
	}

	// dry-run 없이 run 명령을 해석하면 사용 오류로 차단하는지 검증합니다.
	@Test
	func dryRun_없이는_사용_오류로_차단한다() async {
		let result = await CLIApplication.execute(arguments: ["run", "todo-completion"])

		#expect(result.exitStatus == .usageError)
		#expect(result.standardOutput == nil)
		#expect(result.standardError?.contains("--dry-run") == true)
	}

	// scenario 검증 오류의 파일과 JSON key path를 text와 JSON 출력에 보존하는지 검증합니다.
	@Test
	func scenario_검증_오류의_파일과_key_path를_보존한다() async throws {
		let errors = [ScenarioValidationError(
			code: .testDataRequirementResourceEmpty,
			filePath: "/tmp/scenarios/todo-completion.json",
			keyPath: "$.testDataRequirements[0].resource"
		)]
		let command = try runCommand()
		let text = await command.execute(
			format: .text,
			loader: ScenarioValidationFailureLoaderSpy(errors: errors),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			loader: ScenarioValidationFailureLoaderSpy(errors: errors),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))

		#expect(text.exitStatus == .verificationFailure)
		#expect(json.exitStatus == text.exitStatus)
		#expect(try #require(text.standardOutput).contains("$.testDataRequirements[0].resource"))
		#expect(try JSONDecoder().decode(ExecutionPlanValidationFailure.self, from: data) == .init(
			errors: errors
		))
		#expect(text.standardError == nil)
		#expect(json.standardError == nil)
	}

	// run 명령을 dry-run 인수로 해석합니다.
	private func runCommand() throws -> RunCommand {
		let command = try RootCommand.parseAsRoot(["run", "todo-completion", "--dry-run"])

		return try #require(command as? RunCommand)
	}

	// 시험에서 사용할 고정 실행 계획을 반환합니다.
	private func plan() -> ExecutionPlan {
		.init(
			scenarioID: "todo-completion",
			profile: "default",
			outputDirectoryPath: "/tmp/QALenz/Runs",
			testDataRequirements: [.init(operation: .create, resource: "todo:incomplete")],
			targets: [.init(
				target: .init(
					device: "iPhone 16",
					operatingSystem: "iOS 26.0",
					appearance: "light"
				),
				outputDirectoryPath: "/tmp/QALenz/Runs/device=9:iPhone 16",
				steps: [.init(
					id: "launch",
					action: .buildAndRun,
					selector: nil,
					sideEffects: [.appLaunch, .simulatorUse]
				)],
				assertions: [],
				evidence: ["launch"]
			)]
		)
	}
}

// 고정 실행 계획과 요청 config 경로를 기록하는 시험 대역입니다.
private final class ExecutionPlanLoaderSpy: ExecutionPlanLoading, @unchecked Sendable {
	private let plan: ExecutionPlan
	private let lock = NSLock()
	private var receivedConfigurationURLs = [URL]()

	// 반환할 고정 실행 계획으로 시험 대역을 구성합니다.
	init(plan: ExecutionPlan) {
		self.plan = plan
	}

	// 요청 config 경로를 기록하고 고정 실행 계획을 반환합니다.
	func load(scenarioID _: String, at configurationURL: URL) throws -> ExecutionPlan {
		lock.lock()
		defer { lock.unlock() }
		receivedConfigurationURLs.append(configurationURL)

		return plan
	}

	// 기록한 config 경로를 반환합니다.
	func configurationURLs() -> [URL] {
		lock.lock()
		defer { lock.unlock() }

		return receivedConfigurationURLs
	}
}

// scenario 검증 오류를 반환하는 실행 계획 loader 시험 대역입니다.
private struct ScenarioValidationFailureLoaderSpy: ExecutionPlanLoading {
	let errors: [ScenarioValidationError]

	// scenario 검증 오류를 반환합니다.
	func load(scenarioID _: String, at _: URL) throws -> ExecutionPlan {
		throw ScenarioValidationErrors(errors: errors)
	}
}
