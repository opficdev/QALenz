//
//  UIAutomation.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

// XcodeBuildMCP가 반환한 현재 UI snapshot의 식별 정보를 표현합니다.
package struct UIAutomationSnapshot: Codable, Sendable, Equatable {
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

// selector 대기 성공 시 현재 snapshot과 선택적인 element 참조를 함께 전달합니다.
package struct UIAutomationWaitResult: Sendable, Equatable {
	package let snapshot: UIAutomationSnapshot
	package let elementReference: UIElementReference?

	// 현재 snapshot과 선택적인 단일 element 참조로 대기 결과를 구성합니다.
	package init(snapshot: UIAutomationSnapshot, elementReference: UIElementReference? = nil) {
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

// swipe 실행에 필요한 방향, 선택 값과 시간 제한을 함께 전달합니다.
package struct UIAutomationSwipeRequest: Sendable, Equatable {
	package let direction: UISwipeDirection
	package let durationMilliseconds: Int?
	package let distance: Double?
	package let timeoutMilliseconds: Int

	// swipe 실행에 필요한 값을 구성합니다.
	package init(
		direction: UISwipeDirection,
		durationMilliseconds: Int?,
		distance: Double?,
		timeoutMilliseconds: Int
	) {
		self.direction = direction
		self.durationMilliseconds = durationMilliseconds
		self.distance = distance
		self.timeoutMilliseconds = timeoutMilliseconds
	}
}

// UI automation 요청을 XcodeBuildMCP adapter에 위임하는 경계를 정의합니다.
package protocol UIAutomationExecuting: Sendable {
	// 설정한 시간 안에 현재 화면의 UI snapshot을 반환합니다.
	func snapshotUI(
		profile: String,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationSnapshot, RunError>
	// selector가 존재할 때까지 기다리고 현재 참조를 반환합니다.
	func waitForUI(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationWaitResult, RunError>
	// 현재 element 참조를 한 번 tap합니다.
	func tap(
		profile: String,
		elementReference: UIElementReference,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 참조를 지정한 시간만큼 누릅니다.
	func longPress(
		profile: String,
		elementReference: UIElementReference,
		durationMilliseconds: Int?,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 범위에서 지정한 방향으로 swipe합니다.
	func swipe(
		profile: String,
		elementReference: UIElementReference,
		request: UIAutomationSwipeRequest
	) async -> Result<UIAutomationActionResult, RunError>
	// 현재 element 참조에 text를 입력합니다.
	func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError>
}
