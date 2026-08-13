//
//  XcodeBuildMCPRequest.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// 상위 계층이 XcodeBuildMCP command 세부 정보 없이 실행을 요청하는 값입니다.
package struct XcodeBuildMCPRequest: Sendable, Equatable {
	package let operation: XcodeBuildMCPOperation
	package let arguments: [XcodeBuildMCPArgument]

	// operation과 의미 기반 argument로 요청을 구성합니다.
	package init(
		operation: XcodeBuildMCPOperation,
		arguments: [XcodeBuildMCPArgument] = []
	) {
		self.operation = operation
		self.arguments = arguments
	}
}

// QALenz가 요청할 XcodeBuildMCP 작업을 의미 기반 식별자로 표현합니다.
package struct XcodeBuildMCPOperation: RawRepresentable, Sendable, Equatable, Hashable {
	package let rawValue: String

	// 문자열 식별자로 operation을 구성합니다.
	package init(rawValue: String) {
		self.rawValue = rawValue
	}
}

// XcodeBuildMCP command flag와 분리된 의미 기반 argument를 표현합니다.
package struct XcodeBuildMCPArgument: Sendable, Equatable {
	package let name: String
	package let value: String

	// 의미 기반 이름과 값으로 argument를 구성합니다.
	package init(name: String, value: String) {
		self.name = name
		self.value = value
	}
}
