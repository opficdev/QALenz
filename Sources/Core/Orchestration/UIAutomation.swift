//
//  UIAutomation.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

// XcodeBuildMCP가 반환한 현재 UI snapshot의 식별 정보를 표현합니다.
package struct UIAutomationSnapshot: Sendable, Equatable {
	package let screenHash: String
	package let sequence: Int

	// 화면 hash와 순번으로 UI snapshot을 구성합니다.
	package init(screenHash: String, sequence: Int) {
		self.screenHash = screenHash
		self.sequence = sequence
	}
}

// 현재 UI snapshot에서만 유효한 element 참조를 표현합니다.
package struct UIElementReference: Sendable, Equatable {
	package let rawValue: String

	// XcodeBuildMCP element 참조 문자열로 값을 구성합니다.
	package init(rawValue: String) {
		self.rawValue = rawValue
	}
}

// selector 대기 성공 시 현재 snapshot과 선택한 element 참조를 함께 전달합니다.
package struct UIAutomationWaitResult: Sendable, Equatable {
	package let snapshot: UIAutomationSnapshot
	package let elementReference: UIElementReference

	// 현재 snapshot과 단일 element 참조로 대기 결과를 구성합니다.
	package init(snapshot: UIAutomationSnapshot, elementReference: UIElementReference) {
		self.snapshot = snapshot
		self.elementReference = elementReference
	}
}

// UI interaction 뒤에 반환할 최신 snapshot 정보를 표현합니다.
package struct UIAutomationActionResult: Sendable, Equatable {
	package let snapshot: UIAutomationSnapshot?

	// 선택적인 최신 snapshot 정보로 interaction 결과를 구성합니다.
	package init(snapshot: UIAutomationSnapshot? = nil) {
		self.snapshot = snapshot
	}
}

// swipe 방향을 project-owned scenario와 adapter 사이의 공통 값으로 표현합니다.
package enum UISwipeDirection: Sendable, Equatable {
	case upward
	case downward
	case leftward
	case rightward
}

// UI automation 요청을 XcodeBuildMCP adapter에 위임하는 경계를 정의합니다.
package protocol UIAutomationExecuting: Sendable {
	// 현재 화면의 UI snapshot을 반환합니다.
	func snapshotUI(profile: String) async -> Result<UIAutomationSnapshot, RunError>
	// selector가 가리키는 단일 element를 기다리고 현재 참조를 반환합니다.
	func waitForUI(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationWaitResult, RunError>
	// 현재 element 참조를 한 번 tap합니다.
	func tap(
		profile: String,
		elementReference: UIElementReference
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 참조를 지정한 시간만큼 누릅니다.
	func longPress(
		profile: String,
		elementReference: UIElementReference,
		durationMilliseconds: Int?
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 범위에서 지정한 방향으로 swipe합니다.
	func swipe(
		profile: String,
		elementReference: UIElementReference,
		direction: UISwipeDirection,
		durationMilliseconds: Int?,
		distance: Double?
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 참조에 text를 입력합니다.
	func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool
	) async -> Result<UIAutomationActionResult, RunError>
}
