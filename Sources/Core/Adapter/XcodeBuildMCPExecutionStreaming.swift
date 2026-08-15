//
//  XcodeBuildMCPExecutionStreaming.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

// 하나의 XcodeBuildMCP process에서 전달할 진행 사건과 종료 결과를 구분합니다.
package enum XcodeBuildMCPExecutionUpdate: Sendable, Equatable {
	case event(XcodeBuildMCPEvent)
	case completed(XcodeBuildMCPResult)
}

// 단일 XcodeBuildMCP process의 진행 사건과 종료 결과를 전달하는 경계를 정의합니다.
package protocol XcodeBuildMCPExecutionStreaming: Sendable {
	// 요청을 한 번 실행하고 진행 사건과 종료 결과를 순서대로 전달합니다.
	func execution(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPExecutionUpdate, any Error>
}
