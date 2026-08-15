//
//  XcodeBuildMCPOperation+Execution.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

// XcodeBuildMCP 실행 요청의 의미 기반 식별자를 보관합니다.
package extension XcodeBuildMCPOperation {
	static let buildSimulator = Self(rawValue: "build.simulator")
	static let buildAndRunSimulator = Self(rawValue: "simulator.build-and-run")
}
