//
//  XcodeBuildMCPAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Foundation
import Testing
@testable import QALenzCore

@Suite
struct XcodeBuildMCPAdapterTests {
	@Test
	func 의미_기반_요청값이_유지된다() {
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
	func 어댑터_계약이_정규화된_결과를_반환한다() async {
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
	func 어댑터_계약이_정규화된_이벤트를_전달한다() async throws {
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
	func 공통_계약이_Sendable과_Equatable을_충족한다() {
		requireContract(XcodeBuildMCPOperation.self)
		requireContract(XcodeBuildMCPArgument.self)
		requireContract(XcodeBuildMCPRequest.self)
		requireContract(XcodeBuildMCPResult.self)
		requireContract(XcodeBuildMCPEvent.self)
		requireContract(XcodeBuildMCPEvent.Kind.self)
	}

	@Test
	func 큰_정수_payload가_정밀도를_유지한다() throws {
		let payload = try JSONDecoder().decode(
			XcodeBuildMCPPayload.self,
			from: Data("9007199254740993".utf8)
		)

		#expect(payload == .integer(9_007_199_254_740_993))
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
