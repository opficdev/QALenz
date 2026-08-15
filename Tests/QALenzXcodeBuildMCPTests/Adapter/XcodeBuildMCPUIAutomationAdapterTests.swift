//
//  XcodeBuildMCPUIAutomationAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCP UI automation 응답 변환을 검증합니다.
@Suite
struct XcodeBuildMCPUIAutomationAdapterTests {
	// snapshot 요청이 profile을 전달하고 runtime snapshot 식별 정보를 변환하는지 검증합니다.
	@Test
	func snapshot_요청이_profile과_snapshot_식별정보를_변환한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .snapshotUI,
			result: .passed,
			payload: capturePayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let snapshot = try await adapter.snapshotUI(profile: "fixture").get()
		let request = try #require(await spy.requests.first)

		#expect(snapshot == .init(screenHash: "screen-hash", sequence: 4))
		#expect(request == .init(
			operation: .snapshotUI,
			arguments: [.init(name: "profile", value: "fixture")]
		))
	}

	// selector 대기 요청이 selector argument와 현재 element 참조를 변환하는지 검증합니다.
	@Test
	func selector_대기_요청이_selector_argument와_element_참조를_변환한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .waitForUI,
			result: .passed,
			payload: waitPayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let result = try await adapter.waitForUI(
			profile: "fixture",
			selector: .init(identifier: "todo-list", role: "list"),
			timeoutMilliseconds: 5_000
		).get()
		let request = try #require(await spy.requests.first)

		#expect(result == .init(
			snapshot: .init(screenHash: "screen-hash", sequence: 4),
			elementReference: .init(rawValue: "e4")
		))
		#expect(request.arguments == [
			.init(name: "profile", value: "fixture"),
			.init(name: "predicate", value: "exists"),
			.init(name: "timeout.milliseconds", value: "5000"),
			.init(name: "selector.identifier", value: "todo-list"),
			.init(name: "selector.role", value: "list")
		])
	}

	// interaction 요청이 현재 element 참조와 action별 argument를 변환하는지 검증합니다.
	@Test
	func interaction_요청이_action별_argument를_변환한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .tapUI,
			result: .passed,
			payload: capturePayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let reference = UIElementReference(rawValue: "e4")

		_ = try await adapter.tap(profile: "fixture", elementReference: reference).get()
		_ = try await adapter.longPress(
			profile: "fixture",
			elementReference: reference,
			durationMilliseconds: 750
		).get()
		_ = try await adapter.swipe(
			profile: "fixture",
			elementReference: reference,
			direction: .downward,
			durationMilliseconds: 500,
			distance: 0.8
		).get()
		_ = try await adapter.typeText(
			profile: "fixture",
			elementReference: reference,
			text: "new todo",
			replaceExisting: true
		).get()
		let requests = await spy.requests

		#expect(requests.map(\.operation) == [.tapUI, .longPressUI, .swipeUI, .typeTextUI])
		#expect(requests.map(\.arguments) == interactionArguments)
	}

	// interaction 요청별 의미 기반 argument를 구성합니다.
	private var interactionArguments: [[XcodeBuildMCPArgument]] {
		[
			[
				.init(name: "profile", value: "fixture"),
				.init(name: "element.reference", value: "e4")
			],
			[
				.init(name: "profile", value: "fixture"),
				.init(name: "element.reference", value: "e4"),
				.init(name: "duration.seconds", value: "0.75")
			],
			[
				.init(name: "profile", value: "fixture"),
				.init(name: "element.reference", value: "e4"),
				.init(name: "direction", value: "down"),
				.init(name: "duration.seconds", value: "0.5"),
				.init(name: "distance", value: "0.8")
			],
			[
				.init(name: "profile", value: "fixture"),
				.init(name: "element.reference", value: "e4"),
				.init(name: "text", value: "new todo"),
				.init(name: "replace.existing", value: "true")
			]
		]
	}

	// 현재 runtime snapshot을 포함한 UI capture payload를 구성합니다.
	private var capturePayload: XcodeBuildMCPPayload {
		.object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			])
		])
	}

	// selector 대기 성공 payload를 구성합니다.
	private var waitPayload: XcodeBuildMCPPayload {
		.object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			]),
			"waitMatch": .object([
				"matches": .array([.object(["ref": .string("e4")])])
			])
		])
	}
}

// 요청을 기록하고 고정된 결과를 반환하는 XcodeBuildMCP 시험 대역입니다.
private actor XcodeBuildMCPAdapterSpy: XcodeBuildMCPAdapter {
	private let result: XcodeBuildMCPResult
	private(set) var requests: [XcodeBuildMCPRequest] = []

	// 고정된 결과로 시험 대역을 구성합니다.
	init(result: XcodeBuildMCPResult) {
		self.result = result
	}

	// 요청을 기록하고 고정된 결과를 반환합니다.
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		requests.append(request)
		return result
	}

	// 빈 event stream을 반환합니다.
	nonisolated func events(for request: XcodeBuildMCPRequest) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		AsyncThrowingStream { continuation in
			continuation.finish()
		}
	}
}
