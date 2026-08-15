//
//  Target.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// 하나의 device, operatingSystem, appearance 조합을 표현합니다.
import Foundation

package struct Target: Codable, Sendable, Equatable {
	package let device: String
	package let operatingSystem: String
	package let appearance: String
	package let identifier: String

	// 고정된 dimension 순서와 길이 표기를 사용해 target을 구성합니다.
	package init(
		device: String,
		operatingSystem: String,
		appearance: String
	) {
		self.device = device
		self.operatingSystem = operatingSystem
		self.appearance = appearance
		identifier = [
			Self.identifierComponent(name: "device", value: device),
			Self.identifierComponent(name: "operatingSystem", value: operatingSystem),
			Self.identifierComponent(name: "appearance", value: appearance)
		].joined(separator: "|")
	}

	// target identifier를 파일 경로에 사용할 안전한 구성 요소로 반환합니다.
	package var outputDirectoryComponent: String {
		"target-" + identifier.utf8.map { String(format: "%02x", $0) }.joined()
	}

	// 구분자가 값에 포함돼도 충돌하지 않는 identifier 구성 요소를 반환합니다.
	private static func identifierComponent(name: String, value: String) -> String {
		"\(name)=\(value.utf8.count):\(value)"
	}
}
