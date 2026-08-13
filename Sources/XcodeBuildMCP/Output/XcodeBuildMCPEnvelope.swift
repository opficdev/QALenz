//
//  XcodeBuildMCPEnvelope.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import QALenzCore

// XcodeBuildMCP JSON 응답의 공통 envelope를 표현합니다.
struct XcodeBuildMCPEnvelope: Decodable, Sendable, Equatable {
	let schema: String
	let schemaVersion: String
	let didError: Bool
	let error: String?
	let data: XcodeBuildMCPPayload?
	let nextSteps: [String]?
}
