//
//  XcodeBuildMCPAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore

// XcodeBuildMCPAdapter 공통 계약을 검증합니다.
@Suite
struct XcodeBuildMCPAdapterTests {
	// 의미 기반 요청 값의 보존을 검증합니다.
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

	// discovery 작업 식별자가 XcodeBuildMCP 명령 세부 정보와 분리되는지 검증합니다.
	@Test
	func discovery_작업_식별자가_의미를_보존한다() {
		#expect(XcodeBuildMCPOperation.discoverProjects.rawValue == "discover.projects")
		#expect(XcodeBuildMCPOperation.discoverSchemes.rawValue == "discover.schemes")
		#expect(XcodeBuildMCPOperation.discoverSimulators.rawValue == "discover.simulators")
	}

	// adapter 계약이 정규화된 결과를 노출하는지 검증합니다.
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

	// adapter 계약이 정규화된 사건을 전달하는지 검증합니다.
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

	// 공통 값 타입의 동시성 및 동등성 계약을 검증합니다.
	@Test
	func 공통_계약이_Sendable과_Equatable을_충족한다() {
		requireContract(XcodeBuildMCPOperation.self)
		requireContract(XcodeBuildMCPArgument.self)
		requireContract(XcodeBuildMCPRequest.self)
		requireContract(XcodeBuildMCPResult.self)
		requireContract(XcodeBuildMCPEvent.self)
		requireContract(XcodeBuildMCPEvent.Kind.self)
	}

	// 64비트 정수 payload의 정밀도 보존을 검증합니다.
	@Test
	func 큰_정수_payload가_정밀도를_유지한다() throws {
		let payload = try JSONDecoder().decode(
			XcodeBuildMCPPayload.self,
			from: Data("9007199254740993".utf8)
		)

		#expect(payload == .integer(9_007_199_254_740_993))
	}

	// 공통 타입 계약을 컴파일 단계에서 확인합니다.
	private func requireContract<T: Sendable & Equatable>(_: T.Type) {}
}

// adapter 호출 결과를 고정값으로 제공하는 시험 대역입니다.
private struct XcodeBuildMCPAdapterSpy: XcodeBuildMCPAdapter {
	let result: XcodeBuildMCPResult
	let sentEvents: [XcodeBuildMCPEvent]

	// 결과와 선택 사건으로 시험 대역을 구성합니다.
	init(
		result: XcodeBuildMCPResult,
		events: [XcodeBuildMCPEvent] = []
	) {
		self.result = result
		sentEvents = events
	}

	// 고정된 정규화 결과를 반환합니다.
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		result
	}

	// 고정된 정규화 사건 stream을 반환합니다.
	func events(for request: XcodeBuildMCPRequest) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		AsyncThrowingStream { continuation in
			for event in sentEvents {
				continuation.yield(event)
			}
			continuation.finish()
		}
	}
}
