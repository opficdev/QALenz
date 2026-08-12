//
//  XcodeBuildMCPAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Testing
@testable import QALenzCore

@Suite
struct XcodeBuildMCPAdapterTests {
	@Test
	func preservesSemanticRequestValues() {
		let request = XcodeBuildMCPRequest(
			operation: .init(rawValue: "discover.simulators"),
			arguments: [
				.init(name: "project.root", value: "/tmp/Fixture.xcodeproj")
			]
		)

		#expect(request.operation.rawValue == "discover.simulators")
		#expect(request.arguments == [
			.init(name: "project.root", value: "/tmp/Fixture.xcodeproj")
		])
	}

	@Test
	func returnsNormalizedResultThroughAdapterContract() async {
		let request = XcodeBuildMCPRequest(
			operation: .init(rawValue: "discover.simulators")
		)
		let adapter = XcodeBuildMCPAdapterSpy(result: .init(
			operation: request.operation,
			result: .passed
		))

		let result = await adapter.execute(request)

		#expect(result.operation == request.operation)
		#expect(result.result == .passed)
	}

	@Test
	func streamsNormalizedEventsThroughAdapterContract() async throws {
		let request = XcodeBuildMCPRequest(
			operation: .init(rawValue: "discover.simulators")
		)
		let event = XcodeBuildMCPEvent(
			operation: request.operation,
			kind: .progress,
			message: "Discovering simulators"
		)
		let adapter = XcodeBuildMCPAdapterSpy(
			result: .init(operation: request.operation, result: .passed),
			events: [event]
		)
		var receivedEvents: [XcodeBuildMCPEvent] = []

		for try await event in adapter.events(for: request) {
			receivedEvents.append(event)
		}

		#expect(receivedEvents == [event])
	}

	@Test
	func satisfiesSharedContractRequirements() {
		requireContract(XcodeBuildMCPOperation.self)
		requireContract(XcodeBuildMCPArgument.self)
		requireContract(XcodeBuildMCPRequest.self)
		requireContract(XcodeBuildMCPResult.self)
		requireContract(XcodeBuildMCPEvent.self)
		requireContract(XcodeBuildMCPEvent.Kind.self)
	}

	private func requireContract<T: Sendable & Equatable>(_: T.Type) {}
}

private struct XcodeBuildMCPAdapterSpy: XcodeBuildMCPAdapter {
	let result: XcodeBuildMCPResult
	let sentEvents: [XcodeBuildMCPEvent]

	init(
		result: XcodeBuildMCPResult,
		events: [XcodeBuildMCPEvent] = []
	) {
		self.result = result
		sentEvents = events
	}

	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		result
	}

	func events(
		for request: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		AsyncThrowingStream { continuation in
			for event in sentEvents {
				continuation.yield(event)
			}
			continuation.finish()
		}
	}
}
