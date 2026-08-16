//
//  UIStepExecutorTestSupport.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation
@testable import QALenzCore

// UI automation 호출 횟수와 element 참조를 기록하는 시험 대역입니다.
final class UIAutomationSpy: UIAutomationExecuting, @unchecked Sendable {
	private let lock = NSLock()
	private var snapshotResults: [Result<UIAutomationSnapshot, RunError>]
	private var actionResults: [Result<UIAutomationActionResult, RunError>]
	private var waitResults: [Result<UIAutomationWaitResult, RunError>]
	private var references = [String]()
	private var scrollCallsStorage = [UIAutomationScrollCall]()
	private var snapshotCountStorage = 0
	private var waitCountStorage = 0

	// action 결과 순서로 시험 대역을 구성합니다.
	init(
		snapshotResults: [Result<UIAutomationSnapshot, RunError>] = [],
		actionResults: [Result<UIAutomationActionResult, RunError>] = [],
		waitResults: [Result<UIAutomationWaitResult, RunError>] = []
	) {
		self.snapshotResults = snapshotResults
		self.actionResults = actionResults
		self.waitResults = waitResults
	}

	// 기록한 snapshot 요청 횟수를 반환합니다.
	var snapshotCount: Int {
		lock.lock()
		defer { lock.unlock() }
		return snapshotCountStorage
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

	// scroll에 전달한 요청을 반환합니다.
	var scrollCalls: [UIAutomationScrollCall] {
		lock.lock()
		defer { lock.unlock() }
		return scrollCallsStorage
	}

	// 고정된 snapshot을 반환합니다.
	func snapshotUI(
		profile: String,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationSnapshot, RunError> {
		lock.withLock {
			snapshotCountStorage += 1
			return snapshotResults.isEmpty
				? .success(.init(screenHash: "screen", sequence: snapshotCountStorage))
				: snapshotResults.removeFirst()
		}
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

		return lock.withLock {
			waitResults.isEmpty ? .success(.init(
			snapshot: .init(screenHash: "screen", sequence: count),
			elementReference: .init(rawValue: "e\(count)")
			)) : waitResults.removeFirst()
		}
	}

	// tap element 참조를 기록하고 설정한 action 결과를 반환합니다.
	func tap(
		profile: String,
		elementReference: UIElementReference,
		timeoutMilliseconds: Int
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
		durationMilliseconds: Int?,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		.success(.init())
	}

	// scroll에 대한 고정 성공 결과를 반환합니다.
	func scroll(
		profile: String,
		elementReference: UIElementReference,
		request: UIAutomationScrollRequest
	) async -> Result<UIAutomationActionResult, RunError> {
		lock.withLock {
			scrollCallsStorage.append(.init(
				profile: profile,
				elementReference: elementReference,
				request: request
			))
		}
		return .success(.init())
	}

	// type text에 대한 고정 성공 결과를 반환합니다.
	func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		.success(.init())
	}
}

// scroll adapter 호출에 전달한 값을 보관합니다.
struct UIAutomationScrollCall: Equatable {
	let profile: String
	let elementReference: UIElementReference
	let request: UIAutomationScrollRequest
}

// errored 실행 결과의 오류를 반환합니다.
extension RunResult {
	var error: RunError? {
		guard case let .errored(error) = self else { return nil }

		return error
	}
}
