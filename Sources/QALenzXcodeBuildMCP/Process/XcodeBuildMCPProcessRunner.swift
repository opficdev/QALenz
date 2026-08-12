//
//  XcodeBuildMCPProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation

package protocol XcodeBuildMCPProcessRunner: Sendable {
	func events(
		for request: XcodeBuildMCPProcessRequest
	) -> AsyncThrowingStream<XcodeBuildMCPProcessEvent, any Error>
}

extension XcodeBuildMCPProcessRunner {
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

package enum XcodeBuildMCPProcessEvent: Sendable, Equatable {
	case standardOutput(Data)
	case terminated(Int32)
}

package struct XcodeBuildMCPProcessRequest: Sendable, Equatable {
	package let executableURL: URL
	package let arguments: [String]
	package let workingDirectoryURL: URL
	package let environment: [String: String]
	package let timeout: Duration
	package let terminationGracePeriod: Duration

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

package struct XcodeBuildMCPProcessResponse: Sendable, Equatable {
	package let standardOutput: Data
	package let terminationStatus: Int32

	package init(standardOutput: Data, terminationStatus: Int32) {
		self.standardOutput = standardOutput
		self.terminationStatus = terminationStatus
	}
}

package enum XcodeBuildMCPProcessError: Error, Sendable, Equatable {
	case launchFailed
	case timedOut
	case cancelled
}
