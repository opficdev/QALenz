//
//  XcodeBuildMCPCLIAdapter.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import QALenzCore

// 의미 기반 요청을 XcodeBuildMCP CLI 실행으로 연결하고 결과를 정규화합니다.
package struct XcodeBuildMCPCLIAdapter: XcodeBuildMCPAdapter {
	private let configuration: Configuration
	private let commandBuilder: XcodeBuildMCPCommandBuilder
	private let outputDecoder: XcodeBuildMCPOutputDecoder
	private let eventContracts: [
		XcodeBuildMCPOperation: XcodeBuildMCPEventContract
	]
	private let processRunner: any XcodeBuildMCPProcessRunner

	// 실행 설정과 adapter 내부 contract로 운영 adapter를 구성합니다.
	package init(
		configuration: Configuration,
		processRunner: any XcodeBuildMCPProcessRunner = FoundationXcodeBuildMCPProcessRunner()
	) {
		self.init(
			configuration: configuration,
			contracts: .current,
			processRunner: processRunner
		)
	}

	// 시험용 contract와 process 경계를 주입해 adapter를 구성합니다.
	init(
		configuration: Configuration,
		contracts: XcodeBuildMCPContractRegistry,
		processRunner: any XcodeBuildMCPProcessRunner
	) {
		self.configuration = configuration
		commandBuilder = .init(descriptors: contracts.commandDescriptors)
		outputDecoder = .init(outputContracts: contracts.outputContracts)
		eventContracts = contracts.eventContracts
		self.processRunner = processRunner
	}

	// 요청을 JSON 출력 방식으로 실행해 정규화된 최종 결과를 반환합니다.
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

	// 요청을 JSONL 출력 방식으로 실행해 정규화된 진행 사건을 전달합니다.
	package func events(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		AsyncThrowingStream(
			bufferingPolicy: .bufferingNewest(
				configuration.maximumBufferedEventCount
			)
		) { continuation in
			let task = Task {
				await stream(request, continuation: continuation)
			}

			continuation.onTermination = { _ in
				task.cancel()
			}
		}
	}

	// 진행 사건 생산 결과에 따라 stream을 성공 또는 오류로 마무리합니다.
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

	// process 사건을 JSONL decoder에 전달해 QALenz 사건을 생산합니다.
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
		let eventContract = try eventContract(for: request.operation)
		var decoder = XcodeBuildMCPEventDecoder(contract: eventContract)
		var didTerminate = false
		var didReceiveSummary = false

		for try await processEvent in processRunner.events(for: processRequest) {
			switch processEvent {
			case let .standardOutput(data):
				let events = try decoder.decode(
					data,
					operation: request.operation
				)
				for event in events {
					if event.kind == .completed || event.kind == .failed {
						didReceiveSummary = true
					}
					continuation.yield(event)
				}
			case let .terminated(status):
				didTerminate = true
				try validate(status: status, operation: request.operation)

				let events = try decoder.finish(operation: request.operation)
				for event in events {
					if event.kind == .completed || event.kind == .failed {
						didReceiveSummary = true
					}
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
		guard didReceiveSummary else {
			throw runError(
				operation: request.operation,
				code: "adapter.xcodebuildmcp.output.invalid",
				kind: .adapter
			)
		}
	}

	// operation에 대응하는 JSONL event contract를 반환합니다.
	private func eventContract(
		for operation: XcodeBuildMCPOperation
	) throws -> XcodeBuildMCPEventContract {
		guard let contract = eventContracts[operation] else {
			throw runError(
				operation: operation,
				code: "adapter.xcodebuildmcp.command.unsupported",
				kind: .adapter
			)
		}

		return contract
	}

	// process 종료 상태가 성공인지 검증합니다.
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

	// 의미 기반 요청을 자식 process 실행 요청으로 변환합니다.
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
			terminationGracePeriod: configuration.terminationGracePeriod,
			maximumStandardOutputByteCount: output == .json
				? configuration.maximumJSONByteCount
				: nil
		)
	}

	// 발생한 오류를 정규화해 adapter 결과로 구성합니다.
	private func result(
		for error: any Error,
		operation: XcodeBuildMCPOperation
	) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(runError(for: error, operation: operation))
		)
	}

	// process 및 adapter 오류를 공통 RunError로 변환합니다.
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
		case .standardOutputLimitExceeded:
			return runError(
				operation: operation,
				code: "adapter.xcodebuildmcp.output.too-large",
				kind: .adapter
			)
		case .launchFailed, .none:
			return runError(
				operation: operation,
				code: "adapter.xcodebuildmcp.unavailable",
				kind: .adapter
			)
		}
	}

	// 오류 code와 kind를 포함하는 실패 결과를 구성합니다.
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

	// operation 위치를 보존하는 구조화된 RunError를 생성합니다.
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
	// XcodeBuildMCP 실행 파일과 작업 경로 및 process 정책을 보관합니다.
	package struct Configuration: Sendable, Equatable {
		package let executableURL: URL
		package let workingDirectoryURL: URL
		package let environment: [String: String]
		package let timeout: Duration
		package let terminationGracePeriod: Duration
		package let maximumJSONByteCount: Int
		package let maximumBufferedEventCount: Int

		// 환경 변수 허용 목록과 작업 경로를 적용해 실행 설정을 구성합니다.
		package init(
			executableURL: URL,
			workingDirectoryURL: URL,
			environment: [String: String],
			timeout: Duration,
			terminationGracePeriod: Duration,
			maximumJSONByteCount: Int = 1_048_576,
			maximumBufferedEventCount: Int = 64
		) {
			precondition(0 < maximumJSONByteCount)
			precondition(0 < maximumBufferedEventCount)
			self.executableURL = executableURL
			self.workingDirectoryURL = workingDirectoryURL
			var environment = XcodeBuildMCPEnvironmentFilter().apply(
				to: environment
			)
			environment["XCODEBUILDMCP_CWD"] = workingDirectoryURL.path()
			self.environment = environment
			self.timeout = timeout
			self.terminationGracePeriod = terminationGracePeriod
			self.maximumJSONByteCount = maximumJSONByteCount
			self.maximumBufferedEventCount = maximumBufferedEventCount
		}
	}
}
