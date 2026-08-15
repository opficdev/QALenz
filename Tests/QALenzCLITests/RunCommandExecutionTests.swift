//
//  RunCommandExecutionTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

// RunCommand의 non-dry-run 결과 출력을 검증합니다.
@Suite
struct RunCommandExecutionTests {
	// non-dry-run 성공 결과가 저장한 manifest 위치와 JSON 내용을 출력하는지 검증합니다.
	@Test
	func 성공_결과를_manifest로_출력한다() async throws {
		let manifest = try runManifest(result: .passed)
		let execution = SingleTargetRunExecution(
			manifest: manifest,
			manifestURL: URL(fileURLWithPath: "/tmp/QALenz/Runs/manifest.json")
		)
		let command = try command()
		let text = await command.execute(
			format: .text,
			loader: ExecutionPlanLoaderSpy(plan: plan()),
			executor: SingleTargetRunExecutorSpy(result: .success(execution)),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			loader: ExecutionPlanLoaderSpy(plan: plan()),
			executor: SingleTargetRunExecutorSpy(result: .success(execution)),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))

		#expect(text.exitStatus == .success)
		#expect(text.standardOutput == "[passed] /tmp/QALenz/Runs/manifest.json")
		#expect(try RunManifestCodec().decode(data) == manifest)
		#expect(json.exitStatus == .success)
	}

	// non-dry-run 실행기 오류를 execution error 출력으로 변환하는지 검증합니다.
	@Test
	func 실행기_오류를_반환한다() async throws {
		let result = try await command().execute(
			format: .text,
			loader: ExecutionPlanLoaderSpy(plan: plan()),
			executor: SingleTargetRunExecutorSpy(result: .failure(.init(
				kind: .execution,
				code: .init(rawValue: "execution.timeout")
			))),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)

		#expect(result.exitStatus == .executionError)
		#expect(result.standardError?.contains("execution.timeout") == true)
	}

	private func command() throws -> RunCommand {
		let root = try RootCommand.parseAsRoot(["run", "todo-completion"])

		return try #require(root as? RunCommand)
	}

	private func plan() -> ExecutionPlan {
		.init(
			scenarioID: "todo-completion",
			profile: "default",
			outputDirectoryPath: "/tmp/QALenz/Runs",
			testDataRequirements: [],
			targets: []
		)
	}

	private func runManifest(result: RunResult) throws -> RunManifest {
		try .init(
			id: UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600")!,
			createdAt: Date(timeIntervalSince1970: 0),
			scenario: .init(id: "todo-completion", profile: "default"),
			result: result,
			targets: [try .init(
				target: .init(
					device: "iPhone 16",
					operatingSystem: "iOS 26.0",
					appearance: "light"
				),
				result: result,
				stepResults: [.init(stepID: "launch", result: result)],
				evidence: []
			)]
		)
	}
}

private struct ExecutionPlanLoaderSpy: ExecutionPlanLoading {
	let plan: ExecutionPlan

	func load(scenarioID _: String, at _: URL) throws -> ExecutionPlan {
		plan
	}
}

private struct SingleTargetRunExecutorSpy: SingleTargetRunExecuting {
	let result: Result<SingleTargetRunExecution, RunError>

	func execute(_: ExecutionPlan) async -> Result<SingleTargetRunExecution, RunError> {
		result
	}
}
