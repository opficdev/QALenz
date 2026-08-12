//
//  XcodeBuildMCPProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation

// XcodeBuildMCP 자식 process의 출력과 종료 사건을 전달하는 계약입니다.
package protocol XcodeBuildMCPProcessRunner: Sendable {
	// process 실행 중 발생하는 stdout과 종료 상태를 전달합니다.
	func events(
		for request: XcodeBuildMCPProcessRequest
	) -> AsyncThrowingStream<XcodeBuildMCPProcessEvent, any Error>
}

extension XcodeBuildMCPProcessRunner {
	// process 사건을 모아 단일 응답으로 반환합니다.
	package func run(
		_ request: XcodeBuildMCPProcessRequest
	) async throws -> XcodeBuildMCPProcessResponse {
		var standardOutput = Data()
		var terminationStatus: Int32?

		for try await event in events(for: request) {
			switch event {
			case let .standardOutput(data):
				standardOutput.append(data)
			case let .terminated(status):
				terminationStatus = status
			}
		}

		if Task.isCancelled {
			throw XcodeBuildMCPProcessError.cancelled
		}

		guard let terminationStatus else {
			throw XcodeBuildMCPProcessError.launchFailed
		}

		return .init(
			standardOutput: standardOutput,
			terminationStatus: terminationStatus
		)
	}
}

// XcodeBuildMCP 자식 process에서 관측되는 출력과 종료를 표현합니다.
package enum XcodeBuildMCPProcessEvent: Sendable, Equatable {
	case standardOutput(Data)
	case terminated(Int32)
}

// XcodeBuildMCP 자식 process를 시작하는 데 필요한 값을 보관합니다.
package struct XcodeBuildMCPProcessRequest: Sendable, Equatable {
	package let executableURL: URL
	package let arguments: [String]
	package let workingDirectoryURL: URL
	package let environment: [String: String]
	package let timeout: Duration
	package let terminationGracePeriod: Duration

	// 실행 파일, argument, 환경 및 종료 정책으로 요청을 구성합니다.
	package init(
		executableURL: URL,
		arguments: [String],
		workingDirectoryURL: URL,
		environment: [String: String],
		timeout: Duration,
		terminationGracePeriod: Duration
	) {
		self.executableURL = executableURL
		self.arguments = arguments
		self.workingDirectoryURL = workingDirectoryURL
		self.environment = environment
		self.timeout = timeout
		self.terminationGracePeriod = terminationGracePeriod
	}
}

// 자식 process의 stdout과 종료 상태를 보관합니다.
package struct XcodeBuildMCPProcessResponse: Sendable, Equatable {
	package let standardOutput: Data
	package let terminationStatus: Int32

	// stdout과 종료 상태로 process 응답을 구성합니다.
	package init(standardOutput: Data, terminationStatus: Int32) {
		self.standardOutput = standardOutput
		self.terminationStatus = terminationStatus
	}
}

// 자식 process 시작, 시간 초과, 취소 실패를 구분합니다.
package enum XcodeBuildMCPProcessError: Error, Sendable, Equatable {
	case launchFailed
	case timedOut
	case cancelled
}
