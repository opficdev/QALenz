//
//  RunCommandOutputDirectoryTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

// qalenz run의 output directory override 계약을 검증합니다.
@Suite
struct RunCommandOutputDirectoryTests {
	// output directory override를 절대 경로로 출력하지만 디렉터리를 만들지 않는지 검증합니다.
	@Test
	func dryRun이_output_directory_override를_기록하지_않고_계획에만_반영한다() async throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		try writeConfiguration(at: projectURL)
		try writeScenario(at: projectURL)
		let outputDirectoryURL = projectURL
			.deletingLastPathComponent()
			.appendingPathComponent("runs", isDirectory: true)
		let command = try runCommand()

		let result = await command.execute(
			format: .json,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: projectURL
		)
		let data = try #require(result.standardOutput?.data(using: .utf8))
		let plan = try JSONDecoder().decode(ExecutionPlan.self, from: data)

		#expect(result.exitStatus == .success)
		#expect(plan.outputDirectoryPath == outputDirectoryURL.path)
		#expect(!FileManager.default.fileExists(atPath: outputDirectoryURL.path))
	}

	// config output directory가 project 경로이면 override가 없어도 거부하는지 검증합니다.
	@Test
	func dryRun이_project_내_config_output_directory를_거부한다() async throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		try writeConfiguration(at: projectURL, outputDirectory: "..")
		try writeScenario(at: projectURL)
		let command = try runCommand(arguments: ["run", "todo-completion", "--dry-run"])

		let result = await command.execute(
			format: .json,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: projectURL
		)

		#expect(result.exitStatus == .executionError)
	}

	// output directory override가 있는 run 명령을 해석합니다.
	private func runCommand(
		arguments: [String] = [
			"run", "todo-completion", "--dry-run",
			"--output-directory", "../runs"
		]
	) throws -> RunCommand {
		let command = try RootCommand.parseAsRoot(arguments)

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
	private func writeConfiguration(
		at projectURL: URL,
		outputDirectory: String = "../outputs"
	) throws {
		let configurationURL = projectURL
			.appendingPathComponent(".qalenz", isDirectory: true)
			.appendingPathComponent("config.json", isDirectory: false)
		try FileManager.default.createDirectory(
			at: configurationURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		let data = """
			{
			  "schemaVersion": 1,
			  "projectRoot": "..",
			  "xcodeBuildMCPProfile": "default",
			  "scenariosDirectory": "../scenarios",
			  "outputDirectory": "\(outputDirectory)",
			  "targetDefaults": {
				"devices": ["iPhone 16"],
				"operatingSystems": ["iOS 26.0"]
			  },
			  "maximumTargetCount": 12
			}
			"""
		try Data(data.utf8).write(to: configurationURL)
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
			  "testDataRequirements": []
			}
			""".utf8
		).write(to: scenarioURL)
	}
}
