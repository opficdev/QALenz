//
//  XcodeBuildMCPOperation+UIAutomation.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

// UI automation operation의 의미 기반 식별자를 정의합니다.
package extension XcodeBuildMCPOperation {
	static let snapshot = Self(rawValue: "ui.snapshot")
	static let wait = Self(rawValue: "ui.wait")
	static let tap = Self(rawValue: "ui.tap")
	static let longPress = Self(rawValue: "ui.long-press")
	static let swipe = Self(rawValue: "ui.swipe")
	static let typeText = Self(rawValue: "ui.type-text")
}
