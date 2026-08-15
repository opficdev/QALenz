//
//  XcodeBuildMCPOperation+UIAutomation.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

// UI automation operation의 의미 기반 식별자를 정의합니다.
package extension XcodeBuildMCPOperation {
	static let snapshotUI = Self(rawValue: "ui.snapshot")
	static let waitForUI = Self(rawValue: "ui.wait")
	static let tapUI = Self(rawValue: "ui.tap")
	static let longPressUI = Self(rawValue: "ui.long-press")
	static let swipeUI = Self(rawValue: "ui.swipe")
	static let typeTextUI = Self(rawValue: "ui.type-text")
}
