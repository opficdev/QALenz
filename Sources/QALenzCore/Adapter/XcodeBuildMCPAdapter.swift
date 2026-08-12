//
//  XcodeBuildMCPAdapter.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package protocol XcodeBuildMCPAdapter: Sendable {
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult

	func events(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error>
}
