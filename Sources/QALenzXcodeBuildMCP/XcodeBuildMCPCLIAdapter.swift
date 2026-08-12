//
//  XcodeBuildMCPCLIAdapter.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import QALenzCore

package struct XcodeBuildMCPCLIAdapter: XcodeBuildMCPAdapter {
	private let configuration: Configuration
	private let commandBuilder: XcodeBuildMCPCommandBuilder
	private let outputDecoder: XcodeBuildMCPOutputDecoder
	private let processRunner: any XcodeBuildMCPProcessRunner

	package init(
		configuration: Configuration,
		commandBuilder: XcodeBuildMCPCommandBuilder,
		outputDecoder: XcodeBuildMCPOutputDecoder,
		processRunner: any XcodeBuildMCPProcessRunner
	) {
		self.configuration = configuration
		self.commandBuilder = commandBuilder
		self.outputDecoder = outputDecoder
		self.processRunner = processRunner
	}

	package func execute(
		_ request: XcodeBuildMCPRequest
	) async -> XcodeBuildMCPResult {
		do {
			let processRequest = try makeProcessRequest(
				for: request,
				output: .json
			)
			let response = try await processRunner.run(processRequest)

			guard response.terminationStatus == 0 else {
				return failure(
					operation: request.operation,
					code: "adapter.xcodebuildmcp.process.failed",
					kind: .adapter
				)
			}

			return outputDecoder.decode(
				response.standardOutput,
				operation: request.operation
			)
		} catch {
			return result(for: error, operation: request.operation)
		}
	}

	package func events(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		AsyncThrowingStream { continuation in
			let task = Task {
				await stream(request, continuation: continuation)
			}

			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}

	private func stream(
		_ request: XcodeBuildMCPRequest,
		continuation: AsyncThrowingStream<
			XcodeBuildMCPEvent,
			any Error
		>.Continuation
	) async {
		do {
			try await produceEvents(for: request, continuation: continuation)
			continuation.finish()
		} catch {
			continuation.finish(
				throwing: runError(for: error, operation: request.operation)
			)
		}
	}

	private func produceEvents(
		for request: XcodeBuildMCPRequest,
		continuation: AsyncThrowingStream<
			XcodeBuildMCPEvent,
			any Error
		>.Continuation
	) async throws {
		let processRequest = try makeProcessRequest(
			for: request,
			output: .jsonLines
		)
		var decoder = XcodeBuildMCPEventDecoder()
		var didTerminate = false

		for try await processEvent in processRunner.events(for: processRequest) {
			switch processEvent {
			case let .standardOutput(data):
				for event in try decoder.decode(
					data,
					operation: request.operation
				) {
					continuation.yield(event)
				}
			case let .terminated(status):
				didTerminate = true
				try validate(status: status, operation: request.operation)

				for event in try decoder.finish(operation: request.operation) {
					continuation.yield(event)
				}
			}
		}

		guard didTerminate else {
			throw runError(
				operation: request.operation,
				code: "adapter.xcodebuildmcp.process.incomplete",
				kind: .adapter
			)
		}
	}

	private func validate(
		status: Int32,
		operation: XcodeBuildMCPOperation
	) throws {
		guard status == 0 else {
			throw runError(
				operation: operation,
				code: "adapter.xcodebuildmcp.process.failed",
				kind: .adapter
			)
		}
	}

	private func makeProcessRequest(
		for request: XcodeBuildMCPRequest,
		output: XcodeBuildMCPOutputFormat
	) throws -> XcodeBuildMCPProcessRequest {
		let arguments = try commandBuilder.arguments(
			for: request,
			output: output
		)

		return .init(
			executableURL: configuration.executableURL,
			arguments: arguments,
			workingDirectoryURL: configuration.workingDirectoryURL,
			environment: configuration.environment,
			timeout: configuration.timeout,
			terminationGracePeriod: configuration.terminationGracePeriod
		)
	}

	private func result(
		for error: any Error,
		operation: XcodeBuildMCPOperation
	) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(runError(for: error, operation: operation))
		)
	}

	private func runError(
		for error: any Error,
		operation: XcodeBuildMCPOperation
	) -> RunError {
		if let error = error as? RunError {
			return error
		}

		switch error as? XcodeBuildMCPProcessError {
		case .timedOut:
			return runError(
				operation: operation,
				code: "execution.xcodebuildmcp.timeout",
				kind: .execution
			)
		case .cancelled:
			return runError(
				operation: operation,
				code: "execution.xcodebuildmcp.cancelled",
				kind: .execution
			)
		case .launchFailed, .none:
			return runError(
				operation: operation,
				code: "adapter.xcodebuildmcp.unavailable",
				kind: .adapter
			)
		}
	}

	private func failure(
		operation: XcodeBuildMCPOperation,
		code: String,
		kind: RunError.Kind
	) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(
				runError(operation: operation, code: code, kind: kind)
			)
		)
	}

	private func runError(
		operation: XcodeBuildMCPOperation,
		code: String,
		kind: RunError.Kind
	) -> RunError {
		.init(
			kind: kind,
			code: .init(rawValue: code),
			context: .init(command: operation.rawValue)
		)
	}
}

extension XcodeBuildMCPCLIAdapter {
	package struct Configuration: Sendable, Equatable {
		package let executableURL: URL
		package let workingDirectoryURL: URL
		package let environment: [String: String]
		package let timeout: Duration
		package let terminationGracePeriod: Duration

		package init(
			executableURL: URL,
			workingDirectoryURL: URL,
			environment: [String: String],
			timeout: Duration,
			terminationGracePeriod: Duration
		) {
			self.executableURL = executableURL
			self.workingDirectoryURL = workingDirectoryURL
			var environment = XcodeBuildMCPEnvironmentFilter().apply(
				to: environment
			)
			environment["XCODEBUILDMCP_CWD"] = workingDirectoryURL.path()
			self.environment = environment
			self.timeout = timeout
			self.terminationGracePeriod = terminationGracePeriod
		}
	}
}
