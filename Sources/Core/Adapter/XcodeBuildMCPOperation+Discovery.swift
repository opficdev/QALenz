//
//  XcodeBuildMCPOperation+Discovery.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// XcodeBuildMCP discovery 요청의 의미 기반 식별자를 보관합니다.
package extension XcodeBuildMCPOperation {
	static let discoverProjects = Self(rawValue: "discover.projects")
	static let discoverSchemes = Self(rawValue: "discover.schemes")
	static let discoverSimulators = Self(rawValue: "discover.simulators")
}
