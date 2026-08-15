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
			operation: .snapshot,
			result: .passed,
			payload: capturePayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let snapshot = try await adapter.snapshotUI(
			profile: "fixture",
			timeoutMilliseconds: 5_000
		).get()
		let request = try #require(await spy.requests.first)

		#expect(snapshot == .init(screenHash: "screen-hash", sequence: 4))
		#expect(request == .init(
			operation: .snapshot,
			arguments: [.init(name: "profile", value: "fixture")],
			timeout: .milliseconds(5_000)
		))
	}

	// selector 대기 요청이 selector argument와 현재 element 참조를 변환하는지 검증합니다.
	@Test
	func selector_대기_요청이_selector_argument와_element_참조를_변환한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .wait,
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
		#expect(request.timeout == .seconds(6))
	}

	// 복수 selector 매치는 존재 대기 성공으로 처리하고 element 참조를 만들지 않는지 검증합니다.
	@Test
	func selector_대기가_복수_매치에도_성공하고_element_참조를_만들지_않는다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .wait,
			result: .passed,
			payload: multiMatchPayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let result = try await adapter.waitForUI(
			profile: "fixture",
			selector: .init(identifier: "todo-list"),
			timeoutMilliseconds: 5_000
		).get()

		#expect(result.snapshot == .init(screenHash: "screen-hash", sequence: 4))
		#expect(result.elementReference == nil)
	}

	// UI 도구 오류가 오류 코드와 마지막 snapshot을 RunError 문맥으로 변환하는지 검증합니다.
	@Test
	func UI_도구_오류가_오류_코드와_마지막_snapshot을_보존한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .wait,
			result: .errored(.init(
				kind: .adapter,
				code: .init(rawValue: "adapter.xcodebuildmcp.command.failed"),
				context: .init(command: "wait-for-ui")
			)),
			payload: errorPayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let failure = await adapter.waitForUI(
			profile: "fixture",
			selector: .init(identifier: "todo-list"),
			timeoutMilliseconds: 5_000
		).failure
		let error = try #require(failure)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.ui.WAIT_TIMEOUT")
		#expect(error.context.uiSnapshot == .init(screenHash: "screen-hash", sequence: 4))
	}

	// capture가 없는 UI 도구 오류도 구조화 오류 코드로 변환하는지 검증합니다.
	@Test
	func capture가_없는_UI_도구_오류가_구조화_오류_코드를_보존한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .snapshot,
			result: .errored(.init(
				kind: .adapter,
				code: .init(rawValue: "adapter.xcodebuildmcp.command.failed")
			)),
			payload: .object([
				"uiError": .object(["code": .string("SNAPSHOT_CAPTURE_FAILED")])
			])
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let failure = await adapter.snapshotUI(
			profile: "fixture",
			timeoutMilliseconds: 5_000
		).failure
		let error = try #require(failure)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.ui.SNAPSHOT_CAPTURE_FAILED")
		#expect(error.context.uiSnapshot == nil)
	}

	// interaction 요청이 현재 element 참조와 action별 argument를 변환하는지 검증합니다.
	@Test
	func interaction_요청이_action별_argument를_변환한다() async throws {
		let spy = XcodeBuildMCPAdapterSpy(result: .init(
			operation: .tap,
			result: .passed,
			payload: capturePayload
		))
		let adapter = XcodeBuildMCPUIAutomationAdapter(adapter: spy)
		let reference = UIElementReference(rawValue: "e4")

		_ = try await adapter.tap(
			profile: "fixture",
			elementReference: reference,
			timeoutMilliseconds: 5_000
		).get()
		_ = try await adapter.longPress(
			profile: "fixture",
			elementReference: reference,
			durationMilliseconds: 750,
			timeoutMilliseconds: 5_000
		).get()
		_ = try await adapter.scroll(
			profile: "fixture",
			elementReference: reference,
			request: .init(
				direction: .downward,
				durationMilliseconds: 500,
				distance: 0.8,
				timeoutMilliseconds: 5_000
			)
		).get()
		_ = try await adapter.typeText(
			profile: "fixture",
			elementReference: reference,
			text: "new todo",
			replaceExisting: true,
			timeoutMilliseconds: 5_000
		).get()
		let requests = await spy.requests

		#expect(requests.map(\.operation) == [.tap, .longPress, .swipe, .typeText])
		#expect(requests.map(\.arguments) == interactionArguments)
		#expect(requests.map(\.timeout) == Array(repeating: .milliseconds(5_000), count: 4))
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

	// 복수 selector 매치를 포함한 대기 성공 payload를 구성합니다.
	private var multiMatchPayload: XcodeBuildMCPPayload {
		.object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			]),
			"waitMatch": .object([
				"matches": .array([
					.object(["ref": .string("e4")]),
					.object(["ref": .string("e5")])
				])
			])
		])
	}

	// UI 오류 코드와 마지막 snapshot을 포함한 실패 payload를 구성합니다.
	private var errorPayload: XcodeBuildMCPPayload {
		.object([
			"capture": .object([
				"type": .string("runtime-snapshot"),
				"screenHash": .string("screen-hash"),
				"seq": .integer(4)
			]),
			"uiError": .object(["code": .string("WAIT_TIMEOUT")])
		])
	}
}

// Result의 실패 값을 선택적으로 반환합니다.
private extension Result {
	// 실패 값이 있으면 반환합니다.
	var failure: Failure? {
		guard case let .failure(error) = self else { return nil }

		return error
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
