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
		#expect(try #require(result.standardOutput).contains("projectRoot: "))
		#expect(try #require(result.standardOutput).contains("xcodeBuildMCPProfile: "))
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

	// fixture 파일을 읽은 dry-run이 실제 계획을 text와 JSON으로 출력하는지 검증합니다.
	@Test
	func fixture_기반_dryRun이_실제_계획을_출력한다() async throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		try writeConfiguration(at: projectURL)
		try writeScenario(at: projectURL)
		try RunCommandFixture.writeUnrelatedInvalidScenario(at: projectURL)

		let command = try runCommand()
		let text = await command.execute(
			format: .text,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: projectURL
		)
		let json = await command.execute(
			format: .json,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: projectURL
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))
		let plan = try JSONDecoder().decode(ExecutionPlan.self, from: data)
		let outputDirectoryURL = projectURL.appendingPathComponent("outputs", isDirectory: true)

		#expect(text.exitStatus == .success)
		#expect(json.exitStatus == text.exitStatus)
		#expect(try #require(text.standardOutput).contains("scenario: todo-completion"))
		#expect(try #require(text.standardOutput).contains("create | todo:incomplete"))
		#expect(plan.scenarioID == "todo-completion")
		#expect(plan.targets.map(\.target.device) == ["iPhone 17"])
		#expect(plan.testDataRequirements == [.init(
			operation: .create,
			resource: "todo:incomplete"
		)])
		#expect(!FileManager.default.fileExists(atPath: outputDirectoryURL.path))
	}

	// 요청 scenario의 검증 오류는 다른 scenario와 분리해 반환하는지 검증합니다.
	@Test
	func fixture_기반_dryRun이_요청_scenario의_검증_오류를_반환한다() async throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		try writeConfiguration(at: projectURL)
		try RunCommandFixture.writeInvalidRequestedScenario(at: projectURL)
		try RunCommandFixture.writeUnrelatedInvalidScenario(at: projectURL)

		let result = try await runCommand().execute(
			format: .json,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: projectURL
		)
		let data = try #require(result.standardOutput?.data(using: .utf8))
		let failure = try JSONDecoder().decode(ExecutionPlanValidationFailure.self, from: data)
		let scenarioURL = projectURL
			.appendingPathComponent("scenarios", isDirectory: true)
			.appendingPathComponent("todo-completion.json", isDirectory: false)

		#expect(result.exitStatus == .verificationFailure)
		#expect(failure.errors == [.init(
			code: .profileEmpty,
			filePath: scenarioURL.standardizedFileURL.path,
			keyPath: "$.profile"
		)])
	}

	// dry-run 없이 run 명령을 해석하면 실행 경로의 configuration 오류를 반환하는지 검증합니다.
	@Test
	func dryRun_없이는_실행_오류를_반환한다() async {
		let result = await CLIApplication.execute(arguments: ["run", "todo-completion"])

		#expect(result.exitStatus == .executionError)
		#expect(result.standardOutput == nil)
		#expect(result.standardError?.contains("configuration") == true)
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

	// target 입력 오류를 verification failure로 출력하는지 검증합니다.
	@Test
	func target_입력_오류를_verification_failure로_출력한다() async throws {
		let command = try runCommand()
		let result = await command.execute(
			format: .json,
			loader: TargetValidationFailureLoaderSpy(),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(result.standardOutput?.data(using: .utf8))
		let failure = try JSONDecoder().decode(ExecutionPlanValidationFailure.self, from: data)

		#expect(result.exitStatus == .verificationFailure)
		#expect(failure.errors == [.init(
			code: .matrixInvalid,
			filePath: "/tmp/.qalenz/config.json",
			keyPath: "$.matrix"
		)])
	}

	// run 명령을 dry-run 인수로 해석합니다.
	private func runCommand() throws -> RunCommand {
		let command = try RootCommand.parseAsRoot(["run", "todo-completion", "--dry-run"])

		return try #require(command as? RunCommand)
	}

	// fixture를 기록할 임시 project directory를 구성합니다.
	private func makeProjectDirectory() throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

		return url
	}

	// 현재 작업 경로 기준 dry-run config fixture를 기록합니다.
	private func writeConfiguration(at projectURL: URL) throws {
		let configurationURL = projectURL
			.appendingPathComponent(".qalenz", isDirectory: true)
			.appendingPathComponent("config.json", isDirectory: false)
		try FileManager.default.createDirectory(
			at: configurationURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "projectRoot": ".",
			  "xcodeBuildMCPProfile": "default",
			  "scenariosDirectory": "../scenarios",
			  "outputDirectory": "../outputs",
			  "targetDefaults": {
				"devices": ["iPhone 16"],
				"operatingSystems": ["iOS 26.0"]
			  },
			  "maximumTargetCount": 12
			}
			""".utf8
		).write(to: configurationURL)
	}

	// 실행 계획을 생성할 scenario fixture를 기록합니다.
	private func writeScenario(at projectURL: URL) throws {
		let scenarioURL = projectURL
			.appendingPathComponent("scenarios", isDirectory: true)
			.appendingPathComponent("todo-completion.json", isDirectory: false)
		try FileManager.default.createDirectory(
			at: scenarioURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "id": "todo-completion",
			  "name": "Todo 완료 처리",
			  "profile": "default",
			  "matrix": {"devices": ["iPhone 17"]},
			  "steps": [{"id": "launch", "action": "buildAndRun"}],
			  "assertions": [],
			  "evidence": [],
			  "testDataRequirements": [{"operation": "create", "resource": "todo:incomplete"}]
			}
			""".utf8
		).write(to: scenarioURL)
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
					operatingSystem: "iOS 26.0"
				),
				outputDirectoryPath: "/tmp/QALenz/Runs/device=9:iPhone 16",
				steps: [.init(
					id: "launch",
					action: .buildAndRun,
					selector: nil,
					sideEffects: [.appLaunch, .simulatorUse]
				)],
				assertions: [],
				evidence: [.init(afterStepID: "launch")]
			)]
		)
	}
}

// RunCommandTests가 사용하는 scenario fixture를 기록합니다.
private enum RunCommandFixture {
	// 요청 scenario와 무관한 검증 오류를 가진 scenario fixture를 기록합니다.
	static func writeUnrelatedInvalidScenario(at projectURL: URL) throws {
		let scenarioURL = projectURL
			.appendingPathComponent("scenarios", isDirectory: true)
			.appendingPathComponent("invalid.json", isDirectory: false)
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "id": "invalid",
			  "name": "Invalid",
			  "profile": "",
			  "matrix": {},
			  "steps": [{"id": "launch", "action": "buildAndRun"}],
			  "assertions": [],
			  "evidence": [],
			  "testDataRequirements": []
			}
			""".utf8
		).write(to: scenarioURL)
	}

	// 요청 식별자와 일치하지만 profile이 비어 있는 scenario fixture를 기록합니다.
	static func writeInvalidRequestedScenario(at projectURL: URL) throws {
		let scenarioURL = projectURL
			.appendingPathComponent("scenarios", isDirectory: true)
			.appendingPathComponent("todo-completion.json", isDirectory: false)
		try FileManager.default.createDirectory(
			at: scenarioURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "id": "todo-completion",
			  "name": "Todo 완료 처리",
			  "profile": "",
			  "matrix": {},
			  "steps": [{"id": "launch", "action": "buildAndRun"}],
			  "assertions": [],
			  "evidence": [],
			  "testDataRequirements": []
			}
			""".utf8
		).write(to: scenarioURL)
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

// target 입력 오류를 반환하는 실행 계획 loader 시험 대역입니다.
private struct TargetValidationFailureLoaderSpy: ExecutionPlanLoading {
	// matrix 검증 오류를 반환합니다.
	func load(scenarioID _: String, at _: URL) throws -> ExecutionPlan {
		throw TargetValidationError.matrixInvalid
	}
}

// 고정 실행 결과를 반환하는 단일 target 실행기 시험 대역입니다.
