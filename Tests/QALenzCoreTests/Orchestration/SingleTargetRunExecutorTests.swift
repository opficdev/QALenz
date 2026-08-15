//
//  SingleTargetRunExecutorTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// SingleTargetRunExecutor의 단일 process 실행과 manifest 보존을 검증합니다.
@Suite
struct SingleTargetRunExecutorTests {
	// adapter의 성공 결과를 한 번만 요청하고 완료 manifest로 저장하는지 검증합니다.
	@Test
	func 성공_결과를_단일_요청과_manifest로_보존한다() async {
		let adapter = ExecutionAdapterSpy(updates: [.completed(result: .passed)])
		let store = RunManifestStoreSpy()
		let executor = makeExecutor(adapter: adapter, store: store)

		let result = await executor.execute(plan())

		guard case let .success(execution) = result else {
			Issue.record("성공 실행 결과가 반환되지 않음")
			return
		}
		#expect(adapter.requests == [.init(
			operation: .buildAndRunSimulator,
			arguments: [
				.init(name: "profile", value: "default"),
				.init(name: "simulator.name", value: "Fixture Phone")
			]
		)])
		#expect(execution.manifest.result == .passed)
		#expect(store.manifests == [execution.manifest])
	}

	// build-and-run 뒤 UI step을 순서대로 실행하고 snapshot metadata를 보존하는지 검증합니다.
	@Test
	func build_and_run_뒤_UI_step_결과를_manifest로_보존한다() async {
		let adapter = ExecutionAdapterSpy(updates: [.completed(result: .passed)])
		let store = RunManifestStoreSpy()
		let uiAdapter = SnapshotUIAdapterSpy()
		let executor = makeExecutor(
			adapter: adapter,
			store: store,
			uiStepExecutor: .init(adapter: uiAdapter, sleep: { _ in })
		)
		let steps = [
			ExecutionPlanStep(
				id: "build-and-run",
				action: .buildAndRun,
				selector: nil,
				sideEffects: [.appLaunch, .simulatorUse]
			),
			.init(
				id: "snapshot",
				action: .snapshotUI,
				selector: nil,
				sideEffects: [.simulatorUse]
			)
		]

		let result = await executor.execute(plan(steps: steps))

		guard case let .success(execution) = result else {
			Issue.record("UI step 실행 결과가 반환되지 않음")
			return
		}
		#expect(execution.manifest.result == .passed)
		#expect(execution.manifest.targets[0].stepResults.map(\.stepID) == ["build-and-run", "snapshot"])
		#expect(execution.manifest.targets[0].stepResults[1].attempts == 1)
		#expect(execution.manifest.targets[0].stepResults[1].uiSnapshot == .init(
			screenHash: "snapshot-hash",
			sequence: 2
		))
	}

	// build, launch, timeout 오류에서도 완료 manifest를 저장하는지 검증합니다.
	@Test(arguments: [
		"execution.build.failed",
		"execution.launch.failed",
		"execution.timeout"
	])
	func 실행_오류를_manifest로_보존한다(code: String) async {
		let error = RunError(kind: .execution, code: .init(rawValue: code))
		let adapter = ExecutionAdapterSpy(error: error)
		let store = RunManifestStoreSpy()
		let executor = makeExecutor(adapter: adapter, store: store)

		let result = await executor.execute(plan())

		guard case let .success(execution) = result else {
			Issue.record("실행 오류 manifest가 반환되지 않음")
			return
		}
		guard case let .errored(manifestError) = execution.manifest.result else {
			Issue.record("실행 오류가 manifest에 보존되지 않음")
			return
		}
		#expect(manifestError.code.rawValue == code)
		#expect(store.manifests == [execution.manifest])
	}

	// 실행 중인 stream을 취소해 cancellation 오류와 process 취소를 보존하는지 검증합니다.
	@Test
	func 실행_중_cancellation_오류를_manifest로_보존한다() async {
		let adapter = ExecutionAdapterSpy(isPending: true)
		let store = RunManifestStoreSpy()
		let executor = makeExecutor(adapter: adapter, store: store)
		let task = Task { await executor.execute(plan()) }

		while adapter.requests.isEmpty {
			await Task.yield()
		}
		task.cancel()
		let result = await task.value

		guard case let .success(execution) = result,
			case let .errored(error) = execution.manifest.result else {
			Issue.record("cancellation manifest가 반환되지 않음")
			return
		}
		#expect(error.code.rawValue == "execution.cancelled")
		#expect(store.manifests == [execution.manifest])
		#expect(adapter.didCancel)
	}

	// 시험용 단일 target 실행기를 구성합니다.
	private func makeExecutor(
		adapter: any XcodeBuildMCPExecutionStreaming,
		store: any RunManifestStoring,
		uiStepExecutor: UIStepExecutor? = nil
	) -> SingleTargetRunExecutor {
		.init(
			adapter: adapter,
			uiStepExecutor: uiStepExecutor,
			manifestStore: store,
			now: { Date(timeIntervalSince1970: 1_723_718_123) },
			makeID: { UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600")! }
		)
	}

	// 시험용 단일 target 실행 계획을 구성합니다.
	private func plan(steps: [ExecutionPlanStep]? = nil) -> ExecutionPlan {
		.init(
			scenarioID: "fixture",
			profile: "default",
			xcodeBuildMCPProfile: "default",
			outputDirectoryPath: "/tmp/runs",
			testDataRequirements: [],
			targets: [.init(
				target: .init(
					device: "Fixture Phone",
					operatingSystem: "iOS 26.0",
					appearance: "light"
				),
				outputDirectoryPath: "/tmp/runs/fixture",
				steps: steps ?? [.init(
					id: "build-and-run",
					action: .buildAndRun,
					selector: nil,
					sideEffects: [.appLaunch, .simulatorUse]
				)],
				assertions: [],
				evidence: []
			)]
		)
	}
}

// 정해진 terminal 결과 또는 오류를 반환하는 fake adapter입니다.
private final class ExecutionAdapterSpy: XcodeBuildMCPExecutionStreaming, @unchecked Sendable {
	private let updates: [XcodeBuildMCPExecutionUpdate]
	private let error: (any Error)?
	private let isPending: Bool
	private let lock = NSLock()
	private var requestsStorage = [XcodeBuildMCPRequest]()
	private var didCancelStorage = false

	init(
		updates: [XcodeBuildMCPExecutionUpdate] = [],
		error: (any Error)? = nil,
		isPending: Bool = false
	) {
		self.updates = updates
		self.error = error
		self.isPending = isPending
	}

	var requests: [XcodeBuildMCPRequest] {
		lock.lock()
		defer { lock.unlock() }
		return requestsStorage
	}

	var didCancel: Bool {
		lock.lock()
		defer { lock.unlock() }
		return didCancelStorage
	}

	func execution(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPExecutionUpdate, any Error> {
		lock.lock()
		requestsStorage.append(request)
		lock.unlock()

		return .init { continuation in
			guard !isPending else {
				continuation.onTermination = { @Sendable _ in
					self.recordCancellation()
				}
				return
			}
			for update in updates {
				continuation.yield(update)
			}
			if let error {
				continuation.finish(throwing: error)
			} else {
				continuation.finish()
			}
		}
	}

	private func recordCancellation() {
		lock.lock()
		didCancelStorage = true
		lock.unlock()
	}
}

// 저장한 manifest를 보관하는 fake store입니다.
private final class RunManifestStoreSpy: RunManifestStoring, @unchecked Sendable {
	private let lock = NSLock()
	private var manifestsStorage = [RunManifest]()

	var manifests: [RunManifest] {
		lock.lock()
		defer { lock.unlock() }
		return manifestsStorage
	}

	func store(_ manifest: RunManifest, in outputURL: URL) throws -> URL {
		lock.lock()
		manifestsStorage.append(manifest)
		lock.unlock()
		return outputURL.appendingPathComponent("manifest.json")
	}
}

// snapshot UI 요청에 정해진 metadata를 반환하는 시험 대역입니다.
private struct SnapshotUIAdapterSpy: UIAutomationExecuting {
	// 고정된 UI snapshot을 반환합니다.
	func snapshotUI(
		profile: String,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationSnapshot, RunError> {
		.success(.init(screenHash: "snapshot-hash", sequence: 2))
	}

	// 지원하지 않는 UI 대기 오류를 반환합니다.
	func waitForUI(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationWaitResult, RunError> {
		.failure(error)
	}

	// 지원하지 않는 tap 오류를 반환합니다.
	func tap(
		profile: String,
		elementReference: UIElementReference,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		.failure(error)
	}

	// 지원하지 않는 long press 오류를 반환합니다.
	func longPress(
		profile: String,
		elementReference: UIElementReference,
		durationMilliseconds: Int?,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		.failure(error)
	}

	// 지원하지 않는 scroll 오류를 반환합니다.
	func scroll(
		profile: String,
		elementReference: UIElementReference,
		request: UIAutomationScrollRequest
	) async -> Result<UIAutomationActionResult, RunError> {
		.failure(error)
	}

	// 지원하지 않는 type text 오류를 반환합니다.
	func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		.failure(error)
	}

	// 시험 대역의 지원하지 않는 동작 오류를 반환합니다.
	private var error: RunError {
		.init(kind: .adapter, code: .init(rawValue: "fixture.unsupported"))
	}
}

private extension XcodeBuildMCPExecutionUpdate {
	static func completed(result: RunResult) -> Self {
		.completed(.init(operation: .buildAndRunSimulator, result: result))
	}
}
