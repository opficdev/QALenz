//
//  UIStepExecutorTests.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation
import Testing
@testable import QALenzCore

// UI step 실행 정책을 검증합니다.
@Suite
struct UIStepExecutorTests {
	// interaction 실패 뒤 selector를 다시 조회하고 재시도하는지 검증합니다.
	@Test
	func interaction_실패_뒤_새_element_참조로_재시도한다() async {
		let error = RunError(kind: .adapter, code: .init(rawValue: "adapter.action.failed"))
		let spy = UIAutomationSpy(actionResults: [.failure(error), .success(.init())])
		let executor = UIStepExecutor(adapter: spy, sleep: { _ in })

		let execution = await executor.execute(
			step(action: .tap, parameters: ["retryCount": .number("1")]),
			profile: "fixture"
		)

		#expect(execution.result == .passed)
		#expect(execution.attempts == 2)
		#expect(spy.waitCount == 2)
		#expect(spy.tapReferences == ["e1", "e2"])
	}

	// action별 필수 parameter가 없으면 adapter 호출 전에 구조화 오류를 반환하는지 검증합니다.
	@Test
	func typeText_text가_없으면_구조화_오류를_반환한다() async throws {
		let spy = UIAutomationSpy()
		let executor = UIStepExecutor(adapter: spy, sleep: { _ in })

		let execution = await executor.execute(step(action: .typeText), profile: "fixture")
		let error = try #require(execution.result.error)

		#expect(error.code.rawValue == "execution.ui.step.parameters.invalid")
		#expect(error.context.step == "fixture-step")
		#expect(error.context.keyPath == "parameters.text")
		#expect(spy.waitCount == 0)
	}

	// action과 선택 parameter로 execution plan step을 구성합니다.
	private func step(
		action: ScenarioStepAction,
		parameters: [String: ExecutionPlanParameter] = [:]
	) -> ExecutionPlanStep {
		.init(
			id: "fixture-step",
			action: action,
			selector: .init(identifier: "fixture"),
			parameters: .object(parameters),
			sideEffects: [.simulatorUse]
		)
	}
}

// UI automation 호출 횟수와 element 참조를 기록하는 시험 대역입니다.
private final class UIAutomationSpy: UIAutomationExecuting, @unchecked Sendable {
	private let lock = NSLock()
	private var actionResults: [Result<UIAutomationActionResult, RunError>]
	private var references = [String]()
	private var waitCountStorage = 0

	// action 결과 순서로 시험 대역을 구성합니다.
	init(actionResults: [Result<UIAutomationActionResult, RunError>] = []) {
		self.actionResults = actionResults
	}

	// 기록한 selector 대기 횟수를 반환합니다.
	var waitCount: Int {
		lock.lock()
		defer { lock.unlock() }
		return waitCountStorage
	}

	// tap에 전달한 element 참조를 반환합니다.
	var tapReferences: [String] {
		lock.lock()
		defer { lock.unlock() }
		return references
	}

	// 고정된 snapshot을 반환합니다.
	func snapshotUI(profile: String) async -> Result<UIAutomationSnapshot, RunError> {
		.success(.init(screenHash: "screen", sequence: 1))
	}

	// 호출 순서에 따라 새로운 element 참조를 반환합니다.
	func waitForUI(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationWaitResult, RunError> {
		let count = lock.withLock {
			waitCountStorage += 1
			return waitCountStorage
		}

		return .success(.init(
			snapshot: .init(screenHash: "screen", sequence: count),
			elementReference: .init(rawValue: "e\(count)")
		))
	}

	// tap element 참조를 기록하고 설정한 action 결과를 반환합니다.
	func tap(
		profile: String,
		elementReference: UIElementReference
	) async -> Result<UIAutomationActionResult, RunError> {
		let result = lock.withLock {
			references.append(elementReference.rawValue)
			return actionResults.isEmpty ? .success(UIAutomationActionResult()) : actionResults.removeFirst()
		}
		return result
	}

	// long press에 대한 고정 성공 결과를 반환합니다.
	func longPress(
		profile: String,
		elementReference: UIElementReference,
		durationMilliseconds: Int?
	) async -> Result<UIAutomationActionResult, RunError> {
		.success(.init())
	}

	// swipe에 대한 고정 성공 결과를 반환합니다.
	func swipe(
		profile: String,
		elementReference: UIElementReference,
		direction: UISwipeDirection,
		durationMilliseconds: Int?,
		distance: Double?
	) async -> Result<UIAutomationActionResult, RunError> {
		.success(.init())
	}

	// type text에 대한 고정 성공 결과를 반환합니다.
	func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool
	) async -> Result<UIAutomationActionResult, RunError> {
		.success(.init())
	}
}

// errored 실행 결과의 오류를 반환합니다.
private extension RunResult {
	var error: RunError? {
		guard case let .errored(error) = self else { return nil }

		return error
	}
}
