//
//  CommandOutputFormat.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// XcodeBuildMCP CLI가 반환할 출력 형식을 구분합니다.
package enum CommandOutputFormat: String, Sendable, Equatable {
	case json
	case jsonLines = "jsonl"
}
