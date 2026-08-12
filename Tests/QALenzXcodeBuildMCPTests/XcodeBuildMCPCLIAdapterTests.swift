//
//  XcodeBuildMCPCLIAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

@Suite(.serialized)
struct XcodeBuildMCPCLIAdapterTests {
	@Test
	func executesInjectedProcessRunnerWithFilteredConfiguration() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.success")
		let recorder = XcodeBuildMCPProcessRequestRecorder()
		let runner = XcodeBuildMCPProcessRunnerSpy(
			recorder: recorder,
			response: .init(
				standardOutput: successfulEnvelope,
				terminationStatus: 0
			)
		)
		let adapter = makeAdapter(
			operation: operation,
			tool: "success",
			runner: runner,
			environment: [
				"PATH": "/usr/bin",
				"SECRET_TOKEN": "secret-token-value"
			]
		)

		let result = await adapter.execute(.init(operation: operation))
		let requests = await recorder.requests
		let request = try #require(requests.first)

		#expect(result.result == .passed)
		#expect(request.arguments.suffix(2) == ["--output", "json"])
		#expect(request.environment["PATH"] == "/usr/bin")
		#expect(request.environment["SECRET_TOKEN"] == nil)
	}

	@Test
	func executesAgainstFakeExecutable() async {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.success")
		let adapter = makeAdapter(
			operation: operation,
			tool: "success",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)

		let result = await adapter.execute(.init(operation: operation))

		#expect(result.result == .passed)
	}

	@Test
	func hidesStandardErrorFromFailedProcessResult() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.failure")
		let adapter = makeAdapter(
			operation: operation,
			tool: "failure",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)

		let result = await adapter.execute(.init(operation: operation))
		let error = try #require(result.error)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.process.failed")
		#expect(!String(describing: error).contains("secret-token-value"))
	}

	@Test
	func streamsNormalizedEventsFromFakeExecutable() async throws {
		let operation = XcodeBuildMCPOperation(rawValue: "fixture.events")
		let adapter = makeAdapter(
			operation: operation,
			tool: "events",
			runner: FoundationXcodeBuildMCPProcessRunner()
		)
		var events: [XcodeBuildMCPEvent] = []

		for try await event in adapter.events(for: .init(operation: operation)) {
			events.append(event)
		}

		#expect(events.map(\.kind) == [.started, .progress, .completed])
		#expect(events.map(\.message) == [nil, "Working", "SUCCEEDED"])
	}

	private func makeAdapter(
		operation: XcodeBuildMCPOperation,
		tool: String,
		runner: any XcodeBuildMCPProcessRunner,
		environment: [String: String] = [:]
	) -> XcodeBuildMCPCLIAdapter {
		.init(
			configuration: .init(
				executableURL: fakeExecutableURL,
				workingDirectoryURL: FileManager.default.temporaryDirectory,
				environment: environment,
				timeout: .seconds(1),
				terminationGracePeriod: .milliseconds(50)
			),
			commandBuilder: .init(descriptors: [
				operation: .init(workflow: "fixture", tool: tool)
			]),
			outputDecoder: .init(supportedSchemaVersions: [
				"xcodebuildmcp.output.fixture": ["1"]
			]),
			processRunner: runner
		)
	}

	private var fakeExecutableURL: URL {
		Bundle.module.url(
			forResource: "fake-xcodebuildmcp",
			withExtension: nil,
			subdirectory: "Fixtures"
		)!
	}

	private var successfulEnvelope: Data {
		Data(
			"""
			{"schema":"xcodebuildmcp.output.fixture","schemaVersion":"1","didError":false,"error":null,"data":{}}
			""".utf8
		)
	}
}

private actor XcodeBuildMCPProcessRequestRecorder {
	private(set) var requests: [XcodeBuildMCPProcessRequest] = []

	func record(_ request: XcodeBuildMCPProcessRequest) {
		requests.append(request)
	}
}

private struct XcodeBuildMCPProcessRunnerSpy: XcodeBuildMCPProcessRunner {
	let recorder: XcodeBuildMCPProcessRequestRecorder
	let response: XcodeBuildMCPProcessResponse

	func events(
		for request: XcodeBuildMCPProcessRequest
	) -> AsyncThrowingStream<XcodeBuildMCPProcessEvent, any Error> {
		AsyncThrowingStream { continuation in
			Task {
				await recorder.record(request)
				continuation.yield(.standardOutput(response.standardOutput))
				continuation.yield(.terminated(response.terminationStatus))
				continuation.finish()
			}
		}
	}
}

private extension XcodeBuildMCPResult {
	var error: RunError? {
		guard case let .errored(error) = result else { return nil }

		return error
	}
}
