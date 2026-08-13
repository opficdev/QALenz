//
//  XcodeBuildMCPAdapter.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// XcodeBuildMCP 호출을 QALenz 실행 결과와 진행 사건으로 변환하는 계약입니다.
package protocol XcodeBuildMCPAdapter: Sendable {
	// 요청을 실행하고 정규화된 최종 결과를 반환합니다.
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult
	// 요청 실행 중 발생하는 정규화된 진행 사건을 전달합니다.
	func events(for request: XcodeBuildMCPRequest) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error>
}
