//
//  SingleTargetRunExecutor.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// 단일 target run의 종료 결과와 저장한 manifest 위치를 전달합니다.
package struct SingleTargetRunExecution: Sendable, Equatable {
	package let manifest: RunManifest
	package let manifestURL: URL

	// 완료 manifest와 저장 위치로 실행 결과를 구성합니다.
	package init(manifest: RunManifest, manifestURL: URL) {
		self.manifest = manifest
		self.manifestURL = manifestURL
	}
}

// 단일 target 실행에 필요한 build-and-run step과 UI step을 보관합니다.
private struct SingleTargetRunPreflight {
	let target: ExecutionPlanTarget
	let buildStep: ExecutionPlanStep
	let uiSteps: [ExecutionPlanStep]
}

// 단일 target 실행 계획을 실제 run 결과로 변환하는 계약을 정의합니다.
package protocol SingleTargetRunExecuting: Sendable {
	// 한 target의 build-and-run을 실행하고 manifest 저장 결과를 반환합니다.
	func execute(_ plan: ExecutionPlan) async -> Result<SingleTargetRunExecution, RunError>
}

// 단일 build-and-run step을 adapter에 위임하고 완료 manifest를 저장합니다.
package struct SingleTargetRunExecutor: SingleTargetRunExecuting {
	private let adapter: any XcodeBuildMCPExecutionStreaming
	private let uiStepExecutor: UIStepExecutor?
	private let manifestStore: any RunManifestStoring
	private let now: @Sendable () -> Date
	private let makeID: @Sendable () -> UUID

	// adapter, manifest 저장소, 시간 및 식별자 제공자로 실행기를 구성합니다.
	package init(
		adapter: any XcodeBuildMCPExecutionStreaming,
		uiStepExecutor: UIStepExecutor? = nil,
		manifestStore: any RunManifestStoring = RunManifestStore(),
		now: @escaping @Sendable () -> Date = Date.init,
		makeID: @escaping @Sendable () -> UUID = UUID.init
	) {
		self.adapter = adapter
		self.uiStepExecutor = uiStepExecutor
		self.manifestStore = manifestStore
		self.now = now
		self.makeID = makeID
	}

	// 사전 검증을 마친 단일 target build-and-run 결과를 manifest에 보존합니다.
	package func execute(_ plan: ExecutionPlan) async -> Result<SingleTargetRunExecution, RunError> {
		let runPreflight: SingleTargetRunPreflight

		do {
			runPreflight = try preflight(plan)
		} catch let error as RunError {
			return .failure(error)
		} catch {
			return .failure(failure(code: "execution.plan.invalid"))
		}

		let id = makeID()
		let startedAt = now()
		let execution = await executeSteps(
			runPreflight,
			profile: plan.xcodeBuildMCPProfile,
			startedAt: startedAt
		)
		let endedAt = now()

		do {
			let targetResult = try RunTargetResult(
				target: runPreflight.target.target,
				result: execution.result,
				stepResults: execution.stepResults,
				evidence: [],
				startedAt: startedAt,
				endedAt: endedAt
			)
			let manifest = try RunManifest(
				id: id,
				createdAt: startedAt,
				scenario: .init(id: plan.scenarioID, profile: plan.profile),
				result: execution.result,
				targets: [targetResult]
			)
			let manifestURL = try manifestStore.store(
				manifest,
				in: URL(fileURLWithPath: runPreflight.target.outputDirectoryPath, isDirectory: true)
			)

			return .success(.init(manifest: manifest, manifestURL: manifestURL))
		} catch {
			return .failure(failure(code: "execution.manifest.storage.failed"))
		}
	}

	// 실행 계획이 하나의 build-and-run과 뒤이은 UI step만 포함하는지 검증합니다.
	private func preflight(_ plan: ExecutionPlan) throws -> SingleTargetRunPreflight {
		guard plan.targets.count == 1 else {
			throw failure(code: "execution.target.count.unsupported")
		}
		guard plan.testDataRequirements.isEmpty else {
			throw failure(code: "execution.test-data.unsupported")
		}
		guard let target = plan.targets.first,
			target.assertions.isEmpty,
			target.evidence.isEmpty,
			let buildStep = target.steps.first,
			buildStep.action == .buildAndRun else {
			throw failure(code: "execution.step.unsupported")
		}
		let uiSteps = Array(target.steps.dropFirst())
		guard uiSteps.allSatisfy(\.action.isUIAutomationAction) else {
			throw failure(code: "execution.step.unsupported")
		}

		return .init(target: target, buildStep: buildStep, uiSteps: uiSteps)
	}

	// build-and-run 뒤 UI step을 순서대로 실행하고 완료 결과를 보관합니다.
	private func executeSteps(
		_ preflight: SingleTargetRunPreflight,
		profile: String,
		startedAt: Date
	) async -> (result: RunResult, stepResults: [RunStepResult]) {
		let buildResult = await execute(request(for: preflight.target, profile: profile))
		var stepResults = [RunStepResult(
			stepID: preflight.buildStep.id,
			result: buildResult,
			startedAt: startedAt,
			endedAt: now()
		)]
		guard buildResult == .passed else { return (buildResult, stepResults) }

		for step in preflight.uiSteps {
			let stepStartedAt = now()
			let execution = await executeUI(step, profile: profile)
			stepResults.append(.init(
				stepID: step.id,
				result: execution.result,
				attempts: execution.attempts,
				uiSnapshot: execution.snapshot,
				startedAt: stepStartedAt,
				endedAt: now()
			))
			guard execution.result == .passed else { return (execution.result, stepResults) }
		}

		return (.passed, stepResults)
	}

	// UI step 실행기를 통해 한 step을 실행하거나 미구성 오류를 반환합니다.
	private func executeUI(_ step: ExecutionPlanStep, profile: String) async -> UIStepExecution {
		guard let uiStepExecutor else {
			return .init(
				result: .errored(failure(code: "execution.ui.runner.unavailable")),
				attempts: 0,
				snapshot: nil
			)
		}

		return await uiStepExecutor.execute(step, profile: profile)
	}

	// target과 profile을 build-and-run adapter 요청으로 변환합니다.
	private func request(
		for target: ExecutionPlanTarget,
		profile: String
	) -> XcodeBuildMCPRequest {
		.init(
			operation: .buildAndRunSimulator,
			arguments: [
				.init(name: "profile", value: profile),
				.init(name: "simulator.name", value: target.target.device)
			]
		)
	}

	// 한 adapter process의 terminal 결과를 공통 실행 결과로 반환합니다.
	private func execute(_ request: XcodeBuildMCPRequest) async -> RunResult {
		do {
			var terminalResult: XcodeBuildMCPResult?

			for try await update in adapter.execution(for: request) {
				if case let .completed(result) = update {
					terminalResult = result
				}
			}
			if Task.isCancelled {
				return .errored(failure(code: "execution.cancelled"))
			}

			return terminalResult?.result ?? .errored(failure(code: "adapter.xcodebuildmcp.output.invalid"))
		} catch is CancellationError {
			return .errored(failure(code: "execution.cancelled"))
		} catch let error as RunError {
			return .errored(error)
		} catch {
			return .errored(failure(code: "adapter.xcodebuildmcp.process.failed"))
		}
	}

	// 실행 오류를 command 원문 없이 공통 오류로 구성합니다.
	private func failure(code: String) -> RunError {
		.init(
			kind: .execution,
			code: .init(rawValue: code),
			context: .init(command: "run")
		)
	}
}
