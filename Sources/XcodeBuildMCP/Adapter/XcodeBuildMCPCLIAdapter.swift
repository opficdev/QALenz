//
//  XcodeBuildMCPCLIAdapter.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import QALenzCore

// XcodeBuildMCP CLI 요청과 출력을 QALenz 공통 계약으로 변환합니다.
package struct XcodeBuildMCPCLIAdapter: XcodeBuildMCPAdapter, XcodeBuildMCPExecutionStreaming, Sendable {
	static let commandNotFoundStatus: Int32 = 127
	private static let allowedEnvironmentKeys: Set<String> = [
		"DEVELOPER_DIR",
		"PATH",
		"TMPDIR"
	]

	private let commandBuilder: CommandBuilder
	private let outputDecoder: XcodeBuildMCPOutputDecoder
	let eventDescriptors: [XcodeBuildMCPOperation: EventDescriptor]
	let processRunner: any ProcessRunning
	private let workingDirectoryURL: URL
	private let environment: [String: String]
	private let timeout: Duration

	// XcodeBuildMCP 2.x 명세와 process 실행 환경으로 adapter를 구성합니다.
	package init(
		processRunner: any ProcessRunning = FoundationProcessRunner(),
		workingDirectoryURL: URL,
		environment: [String: String],
		timeout: Duration
	) {
		self.init(
			commandBuilder: XcodeBuildMCPV2.commandBuilder,
			outputDecoder: XcodeBuildMCPV2.outputDecoder,
			eventDescriptors: XcodeBuildMCPV2.eventDescriptors,
			processRunner: processRunner,
			workingDirectoryURL: workingDirectoryURL,
			environment: environment,
			timeout: timeout
		)
	}

	// command, 출력 decoder, process 실행 경계와 실행 환경으로 adapter를 구성합니다.
	init(
		commandBuilder: CommandBuilder,
		outputDecoder: XcodeBuildMCPOutputDecoder,
		eventDescriptors: [XcodeBuildMCPOperation: EventDescriptor],
		processRunner: any ProcessRunning = FoundationProcessRunner(),
		workingDirectoryURL: URL,
		environment: [String: String],
		timeout: Duration
	) {
		self.commandBuilder = commandBuilder
		self.outputDecoder = outputDecoder
		self.eventDescriptors = eventDescriptors
		self.processRunner = processRunner
		self.workingDirectoryURL = workingDirectoryURL
		self.environment = environment
		self.timeout = timeout
	}

	// operation이 JSONL 진행 사건을 지원하는지 반환합니다.
	package func supportsEvents(for operation: XcodeBuildMCPOperation) -> Bool {
		eventDescriptors[operation] != nil
	}

	// JSON 출력 command를 실행하고 공통 실행 결과를 반환합니다.
	package func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		do {
			let result = try await run(request, output: .json)

			guard result.terminationStatus == 0 else {
				return .init(
					operation: request.operation,
					result: .errored(terminationError(
						operation: request.operation,
						status: result.terminationStatus
					))
				)
			}

			return outputDecoder.decode(result.standardOutput, operation: request.operation)
		} catch {
			return .init(
				operation: request.operation,
				result: .errored(normalizedError(operation: request.operation, error: error))
			)
		}
	}

	// JSONL 출력 command를 실행하고 공통 진행 사건 stream을 반환합니다.
	package func events(for request: XcodeBuildMCPRequest) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		.init { continuation in
			let task = Task {
				do {
					guard let descriptor = eventDescriptors[request.operation] else {
						throw failureError(
							operation: request.operation,
							kind: .adapter,
							code: "adapter.xcodebuildmcp.event.unsupported"
						)
					}

					var decoder = XcodeBuildMCPEventDecoder(descriptor: descriptor)
					let processRequest = try processRequest(for: request, output: .jsonLines)
					var didTerminate = false

					for try await processEvent in processRunner.events(for: processRequest) {
						switch processEvent {
						case let .standardOutput(data):
							for event in try decoder.decode(data, operation: request.operation) {
								continuation.yield(event)
							}
						case let .terminated(status):
							didTerminate = true
							guard status == 0 else {
								throw terminationError(
									operation: request.operation,
									status: status
								)
							}
							for event in try decoder.finish(operation: request.operation) {
								continuation.yield(event)
							}
						}
					}

					guard didTerminate else {
						throw failureError(
							operation: request.operation,
							kind: .adapter,
							code: "adapter.xcodebuildmcp.process.failed"
						)
					}
					continuation.finish()
				} catch {
					continuation.finish(
						throwing: normalizedError(operation: request.operation, error: error)
					)
				}
			}

			continuation.onTermination = { @Sendable _ in
				task.cancel()
			}
		}
	}

	// 요청과 출력 형식으로 XcodeBuildMCP CLI process를 실행합니다.
	private func run(
		_ request: XcodeBuildMCPRequest,
		output: CommandOutputFormat
	) async throws -> ProcessResult {
		try await processRunner.run(processRequest(for: request, output: output))
	}

	// 요청과 출력 형식으로 허용된 process 실행 요청을 생성합니다.
	func processRequest(
		for request: XcodeBuildMCPRequest,
		output: CommandOutputFormat
	) throws -> ProcessRequest {
		let arguments = try commandBuilder.arguments(for: request, output: output)

		return .init(
			executableURL: URL(fileURLWithPath: "/usr/bin/env"),
			arguments: ["xcodebuildmcp"] + arguments,
			workingDirectoryURL: workingDirectoryURL,
			environment: allowedEnvironment,
			timeout: timeout
		)
	}

	// process 실행에 전달할 허용된 환경 값만 반환합니다.
	private var allowedEnvironment: [String: String] {
		environment.filter { Self.allowedEnvironmentKeys.contains($0.key) }
	}

	// 실행 경계 오류를 원본 내용을 포함하지 않는 RunError로 변환합니다.
	func normalizedError(
		operation: XcodeBuildMCPOperation,
		error: any Error
	) -> RunError {
		if let error = error as? RunError {
			return error
		}
		if error is CancellationError {
			return failureError(
				operation: operation,
				kind: .execution,
				code: "execution.cancelled"
			)
		}
		if let error = error as? ProcessRunnerError {
			switch error {
			case .timedOut:
				return failureError(
					operation: operation,
					kind: .execution,
					code: "execution.timeout"
				)
			case .executableUnavailable:
				return failureError(
					operation: operation,
					kind: .adapter,
					code: "adapter.xcodebuildmcp.unavailable"
				)
			case .invalidWorkingDirectory, .failedToLaunch:
				return failureError(
					operation: operation,
					kind: .adapter,
					code: "adapter.xcodebuildmcp.process.failed"
				)
			}
		}

		return failureError(
			operation: operation,
			kind: .adapter,
			code: "adapter.xcodebuildmcp.process.failed"
		)
	}

	// 공통 실행 결과에 포함할 오류 결과를 생성합니다.
	private func failure(
		operation: XcodeBuildMCPOperation,
		kind: RunError.Kind,
		code: String
	) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(failureError(operation: operation, kind: kind, code: code))
		)
	}

	// env 종료 상태를 CLI 미설치와 command 실패 오류로 구분합니다.
	func terminationError(
		operation: XcodeBuildMCPOperation,
		status: Int32
	) -> RunError {
		let code = switch status {
		case Self.commandNotFoundStatus:
			"adapter.xcodebuildmcp.unavailable"
		default:
			"adapter.xcodebuildmcp.command.failed"
		}

		return failureError(
			operation: operation,
			kind: .adapter,
			code: code
		)
	}

	// 원본 process 출력 없이 구조화된 오류를 생성합니다.
	func failureError(
		operation: XcodeBuildMCPOperation,
		kind: RunError.Kind,
		code: String
	) -> RunError {
		.init(
			kind: kind,
			code: .init(rawValue: code),
			context: .init(command: operation.rawValue)
		)
	}
}
