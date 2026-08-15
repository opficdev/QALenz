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

// 단일 target 실행 계획을 실제 run 결과로 변환하는 계약을 정의합니다.
package protocol SingleTargetRunExecuting: Sendable {
	// 한 target의 build-and-run을 실행하고 manifest 저장 결과를 반환합니다.
	func execute(_ plan: ExecutionPlan) async -> Result<SingleTargetRunExecution, RunError>
}

// 단일 build-and-run step을 adapter에 위임하고 완료 manifest를 저장합니다.
package struct SingleTargetRunExecutor: SingleTargetRunExecuting {
	private let adapter: any XcodeBuildMCPExecutionStreaming
	private let manifestStore: any RunManifestStoring
	private let now: @Sendable () -> Date
	private let makeID: @Sendable () -> UUID

	// adapter, manifest 저장소, 시간 및 식별자 제공자로 실행기를 구성합니다.
	package init(
		adapter: any XcodeBuildMCPExecutionStreaming,
		manifestStore: any RunManifestStoring = RunManifestStore(),
		now: @escaping @Sendable () -> Date = Date.init,
		makeID: @escaping @Sendable () -> UUID = UUID.init
	) {
		self.adapter = adapter
		self.manifestStore = manifestStore
		self.now = now
		self.makeID = makeID
	}

	// 사전 검증을 마친 단일 target build-and-run 결과를 manifest에 보존합니다.
	package func execute(_ plan: ExecutionPlan) async -> Result<SingleTargetRunExecution, RunError> {
		let target: ExecutionPlanTarget
		let step: ExecutionPlanStep

		do {
			(target, step) = try preflight(plan)
		} catch let error as RunError {
			return .failure(error)
		} catch {
			return .failure(failure(code: "execution.plan.invalid"))
		}

		let id = makeID()
		let startedAt = now()
		let result = await execute(request(for: target, profile: plan.xcodeBuildMCPProfile))
		let endedAt = now()

		do {
			let stepResult = RunStepResult(
				stepID: step.id,
				result: result,
				startedAt: startedAt,
				endedAt: endedAt
			)
			let targetResult = try RunTargetResult(
				target: target.target,
				result: result,
				stepResults: [stepResult],
				evidence: [],
				startedAt: startedAt,
				endedAt: endedAt
			)
			let manifest = try RunManifest(
				id: id,
				createdAt: startedAt,
				scenario: .init(id: plan.scenarioID, profile: plan.profile),
				result: result,
				targets: [targetResult]
			)
			let manifestURL = try manifestStore.store(
				manifest,
				in: URL(fileURLWithPath: target.outputDirectoryPath, isDirectory: true)
			)

			return .success(.init(manifest: manifest, manifestURL: manifestURL))
		} catch {
			return .failure(failure(code: "execution.manifest.storage.failed"))
		}
	}

	// 실행 계획이 하나의 build-and-run target만 포함하는지 검증합니다.
	private func preflight(_ plan: ExecutionPlan) throws -> (ExecutionPlanTarget, ExecutionPlanStep) {
		guard plan.targets.count == 1 else {
			throw failure(code: "execution.target.count.unsupported")
		}
		guard plan.testDataRequirements.isEmpty else {
			throw failure(code: "execution.test-data.unsupported")
		}
		guard let target = plan.targets.first,
			target.assertions.isEmpty,
			target.evidence.isEmpty,
			target.steps.count == 1,
			let step = target.steps.first,
			step.action == .buildAndRun else {
			throw failure(code: "execution.step.unsupported")
		}

		return (target, step)
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
