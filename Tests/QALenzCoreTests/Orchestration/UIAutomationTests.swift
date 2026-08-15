//
//  UIAutomationTests.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Testing
@testable import QALenzCore

// UI automation 공통 계약을 검증합니다.
@Suite
struct UIAutomationTests {
	// UI operation 식별자가 XcodeBuildMCP command와 분리되는지 검증합니다.
	@Test
	func UI_automation_작업_식별자가_의미를_보존한다() {
		#expect(XcodeBuildMCPOperation.snapshotUI.rawValue == "ui.snapshot")
		#expect(XcodeBuildMCPOperation.waitForUI.rawValue == "ui.wait")
		#expect(XcodeBuildMCPOperation.tapUI.rawValue == "ui.tap")
		#expect(XcodeBuildMCPOperation.longPressUI.rawValue == "ui.long-press")
		#expect(XcodeBuildMCPOperation.swipeUI.rawValue == "ui.swipe")
		#expect(XcodeBuildMCPOperation.typeTextUI.rawValue == "ui.type-text")
	}

	// UI automation 값이 동시성과 동등성 계약을 충족하는지 검증합니다.
	@Test
	func UI_automation_값이_공통_계약을_충족한다() {
		requireContract(UIAutomationSnapshot.self)
		requireContract(UIElementReference.self)
		requireContract(UIAutomationWaitResult.self)
		requireContract(UIAutomationActionResult.self)
		requireContract(UISwipeDirection.self)
	}

	// 공통 값 계약을 컴파일 단계에서 확인합니다.
	private func requireContract<T: Sendable & Equatable>(_: T.Type) {}
}
