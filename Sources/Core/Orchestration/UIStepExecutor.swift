//
//  UIStepExecutor.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation

// UI step 실행 결과와 최신 snapshot 정보를 함께 보관합니다.
package struct UIStepExecution: Sendable, Equatable {
	package let result: RunResult
	package let attempts: Int
	package let snapshot: UIAutomationSnapshot?
	package let isRetryable: Bool

	// 실행 결과, 시도 횟수, 최신 snapshot과 재시도 가능 여부로 값을 구성합니다.
	package init(
		result: RunResult,
		attempts: Int,
		snapshot: UIAutomationSnapshot?,
		isRetryable: Bool = false
	) {
		self.result = result
		self.attempts = attempts
		self.snapshot = snapshot
		self.isRetryable = isRetryable
	}
}

// UI step의 재시도, 지연, 최신 element 참조 정책을 Core에서 실행합니다.
package struct UIStepExecutor: Sendable {
	private let adapter: any UIAutomationExecuting
	private let sleep: @Sendable (Int) async throws -> Void

	// UI automation adapter와 지연 제공자로 실행기를 구성합니다.
	package init(
		adapter: any UIAutomationExecuting,
		sleep: @escaping @Sendable (Int) async throws -> Void = Self.sleep
	) {
		self.adapter = adapter
		self.sleep = sleep
	}

	// 한 UI step을 실행하고 각 재시도 전에 새 element 참조를 얻습니다.
	package func execute(
		_ step: ExecutionPlanStep,
		profile: String
	) async -> UIStepExecution {
		do {
			let configuration = try UIStepConfiguration(step: step)
			return await execute(step, profile: profile, configuration: configuration)
		} catch let error as RunError {
			return .init(result: .errored(error), attempts: 0, snapshot: nil)
		} catch {
			return .init(
				result: .errored(failure(step: step, code: "execution.ui.step.parameters.invalid")),
				attempts: 0,
				snapshot: nil
			)
		}
	}

	// 검증된 UI step을 재시도 정책에 따라 실행합니다.
	private func execute(
		_ step: ExecutionPlanStep,
		profile: String,
		configuration: UIStepConfiguration
	) async -> UIStepExecution {
		var lastResult = RunResult.errored(failure(step: step, code: "execution.ui.step.unavailable"))
		var lastSnapshot: UIAutomationSnapshot?

		for attempt in 1...(configuration.retryCount + 1) {
			if let execution = await executeAttempt(
				step,
				profile: profile,
				configuration: configuration,
				lastSnapshot: &lastSnapshot
			) {
				if execution.result == .passed {
					do {
						try await sleep(configuration.postDelayMilliseconds)
					} catch {
						return .init(
							result: .errored(failure(step: step, code: "execution.cancelled")),
							attempts: attempt,
							snapshot: execution.snapshot
						)
					}
					return .init(result: .passed, attempts: attempt, snapshot: execution.snapshot)
				}
				lastResult = execution.result
				guard execution.isRetryable else {
					return .init(
						result: execution.result,
						attempts: attempt,
						snapshot: execution.snapshot
					)
				}
			}
		}

		return .init(
			result: lastResult,
			attempts: configuration.retryCount + 1,
			snapshot: lastSnapshot
		)
	}

	// 한 번의 UI step 시도에서 지연, 최신 selector 대기 및 action을 순서대로 수행합니다.
	private func executeAttempt(
		_ step: ExecutionPlanStep,
		profile: String,
		configuration: UIStepConfiguration,
		lastSnapshot: inout UIAutomationSnapshot?
	) async -> UIStepExecution? {
		do {
			try await sleep(configuration.preDelayMilliseconds)
		} catch {
			return .init(
				result: .errored(failure(step: step, code: "execution.cancelled")),
				attempts: 1,
				snapshot: lastSnapshot
			)
		}

		switch step.action {
		case .snapshotUI:
			let result = await adapter.snapshotUI(
				profile: profile,
				timeoutMilliseconds: configuration.timeoutMilliseconds
			)
			return capture(result, step: step, lastSnapshot: &lastSnapshot)
		case .waitForUI:
			guard let selector = step.selector else {
				return selectorMissingExecution(step: step, snapshot: lastSnapshot)
			}
			let result = await adapter.waitForUI(
				profile: profile,
				selector: selector,
				timeoutMilliseconds: configuration.timeoutMilliseconds
			)
			return wait(result, step: step, lastSnapshot: &lastSnapshot)
		case .tap, .longPress, .swipe, .typeText:
			return await executeInteraction(
				step,
				profile: profile,
				configuration: configuration,
				lastSnapshot: &lastSnapshot
			)
		case .buildAndRun, .screenshot, .recordVideo:
			return .init(
				result: .errored(failure(step: step, code: "execution.ui.step.unsupported")),
				attempts: 1,
				snapshot: lastSnapshot
			)
		}
	}

	// interaction 전에 selector를 다시 대기하고 성공 뒤 post-delay를 적용합니다.
	private func executeInteraction(
		_ step: ExecutionPlanStep,
		profile: String,
		configuration: UIStepConfiguration,
		lastSnapshot: inout UIAutomationSnapshot?
	) async -> UIStepExecution {
		guard let selector = step.selector else {
			return selectorMissingExecution(step: step, snapshot: lastSnapshot)
		}
		let waitResult = await adapter.waitForUI(
			profile: profile,
			selector: selector,
			timeoutMilliseconds: configuration.timeoutMilliseconds
		)
		guard case let .success(waitResult) = waitResult else {
			return wait(waitResult, step: step, lastSnapshot: &lastSnapshot)
		}
		lastSnapshot = waitResult.snapshot
		guard let elementReference = waitResult.elementReference else {
			return .init(
				result: .errored(failure(step: step, code: "execution.ui.selector.ambiguous")),
				attempts: 1,
				snapshot: lastSnapshot
			)
		}
		let actionResult = await action(
			step.action,
			profile: profile,
			elementReference: elementReference,
			configuration: configuration
		)
		return action(actionResult, step: step, lastSnapshot: &lastSnapshot)
	}

	// 현재 element 참조와 action별 parameter를 adapter 요청으로 변환합니다.
	private func action(
		_ action: ScenarioStepAction,
		profile: String,
		elementReference: UIElementReference,
		configuration: UIStepConfiguration
	) async -> Result<UIAutomationActionResult, RunError> {
		switch action {
		case .tap:
			return await adapter.tap(
				profile: profile,
				elementReference: elementReference,
				timeoutMilliseconds: configuration.timeoutMilliseconds
			)
		case .longPress:
			return await adapter.longPress(
				profile: profile,
				elementReference: elementReference,
				durationMilliseconds: configuration.durationMilliseconds,
				timeoutMilliseconds: configuration.timeoutMilliseconds
			)
		case .swipe:
			guard let direction = configuration.swipeDirection else {
				return .failure(failure(step: nil, code: "execution.ui.step.parameters.invalid"))
			}
			return await adapter.swipe(
				profile: profile,
				elementReference: elementReference,
				request: .init(
					direction: direction,
					durationMilliseconds: configuration.durationMilliseconds,
					distance: configuration.distance,
					timeoutMilliseconds: configuration.timeoutMilliseconds
				)
			)
		case .typeText:
			guard let text = configuration.text else {
				return .failure(failure(step: nil, code: "execution.ui.step.parameters.invalid"))
			}
			return await adapter.typeText(
				profile: profile,
				elementReference: elementReference,
				text: text,
				replaceExisting: configuration.replaceExisting,
				timeoutMilliseconds: configuration.timeoutMilliseconds
			)
		case .buildAndRun, .waitForUI, .snapshotUI, .screenshot, .recordVideo:
			return .failure(failure(step: nil, code: "execution.ui.step.unsupported"))
		}
	}

}

// UI step 결과 정규화와 시간 제한 보조 동작을 구현합니다.
private extension UIStepExecutor {
	// snapshot 요청 성공 또는 오류를 UI step 실행 결과로 변환합니다.
	private func capture(
		_ result: Result<UIAutomationSnapshot, RunError>,
		step: ExecutionPlanStep,
		lastSnapshot: inout UIAutomationSnapshot?
	) -> UIStepExecution {
		switch result {
		case let .success(snapshot):
			lastSnapshot = snapshot
			return .init(result: .passed, attempts: 1, snapshot: snapshot)
		case let .failure(error):
			let snapshot = error.context.uiSnapshot ?? lastSnapshot
			lastSnapshot = snapshot
			return .init(
				result: .errored(contextual(error, step: step)),
				attempts: 1,
				snapshot: snapshot,
				isRetryable: error.code.rawValue != "execution.cancelled"
			)
		}
	}

	// selector 대기 성공 또는 오류를 UI step 실행 결과로 변환합니다.
	private func wait(
		_ result: Result<UIAutomationWaitResult, RunError>,
		step: ExecutionPlanStep,
		lastSnapshot: inout UIAutomationSnapshot?
	) -> UIStepExecution {
		switch result {
		case let .success(waitResult):
			lastSnapshot = waitResult.snapshot
			return .init(result: .passed, attempts: 1, snapshot: waitResult.snapshot)
		case let .failure(error):
			let snapshot = error.context.uiSnapshot ?? lastSnapshot
			lastSnapshot = snapshot
			return .init(
				result: .errored(contextual(error, step: step)),
				attempts: 1,
				snapshot: snapshot,
				isRetryable: error.code.rawValue != "execution.cancelled"
			)
		}
	}

	// action 성공 또는 오류를 UI step 실행 결과로 변환합니다.
	private func action(
		_ result: Result<UIAutomationActionResult, RunError>,
		step: ExecutionPlanStep,
		lastSnapshot: inout UIAutomationSnapshot?
	) -> UIStepExecution {
		switch result {
		case let .success(actionResult):
			lastSnapshot = actionResult.snapshot ?? lastSnapshot
			return .init(result: .passed, attempts: 1, snapshot: lastSnapshot)
		case let .failure(error):
			let snapshot = error.context.uiSnapshot ?? lastSnapshot
			lastSnapshot = snapshot
			return .init(result: .errored(contextual(error, step: step)), attempts: 1, snapshot: snapshot)
		}
	}

	// 지연 시간이 양수일 때만 취소 가능한 sleep을 수행합니다.
	private static func sleep(milliseconds: Int) async throws {
		guard 0 < milliseconds else { return }

		try await Task.sleep(for: .milliseconds(milliseconds))
	}

	// step 식별자를 포함한 실행 오류를 구성합니다.
	private func failure(step: ExecutionPlanStep?, code: String) -> RunError {
		.init(
			kind: .execution,
			code: .init(rawValue: code),
			context: .init(step: step?.id)
		)
	}

	// selector가 없는 UI step의 실행 오류를 구성합니다.
	private func selectorMissingExecution(
		step: ExecutionPlanStep,
		snapshot: UIAutomationSnapshot?
	) -> UIStepExecution {
		.init(
			result: .errored(failure(step: step, code: "execution.ui.selector.missing")),
			attempts: 1,
			snapshot: snapshot
		)
	}

	// adapter 오류에 현재 step 식별자를 보강합니다.
	private func contextual(_ error: RunError, step: ExecutionPlanStep) -> RunError {
		.init(kind: error.kind, code: error.code, context: .init(
			command: error.context.command,
			target: error.context.target,
			step: step.id,
			assertion: error.context.assertion,
			filePath: error.context.filePath,
			keyPath: error.context.keyPath,
			uiSnapshot: error.context.uiSnapshot
		))
	}
}
