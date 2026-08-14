//
//  XcodeBuildMCPDiscoveryProviderTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPDiscoveryProvider의 조회 조합 계약을 검증합니다.
@Suite
struct XcodeBuildMCPDiscoveryProviderTests {
	// project, workspace, scheme, Simulator 조회를 하나의 정규화 결과로 조합하는지 검증합니다.
	@Test
	func 조회_결과를_정규화된_discovery_후보로_조합한다() async throws {
		let rootURL = URL(fileURLWithPath: "/tmp/Fixture", isDirectory: true)
		let adapter = XcodeBuildMCPAdapterSpy { request in
			switch request.operation {
			case .discoverProjects:
				projectResult()
			case .discoverSchemes:
				schemeResult(for: request)
			case .discoverSimulators:
				simulatorResult()
			default:
				unexpectedResult(for: request.operation)
			}
		}
		let provider = XcodeBuildMCPDiscoveryProvider(adapter: adapter)

		let result = try await provider.discover(at: rootURL)
		let requests = await adapter.requests()

		#expect(result == .init(
			projectURLs: [
				rootURL.appendingPathComponent("Alpha.xcodeproj"),
				rootURL.appendingPathComponent("Beta.xcodeproj")
			],
			workspaceURLs: [rootURL.appendingPathComponent("Fixture.xcworkspace")],
			schemeNames: ["App", "Library", "App"],
			simulators: [.init(
				name: "iPhone 17",
				simulatorId: "simulator-id",
				state: "Shutdown",
				runtime: "iOS 26.0",
				isAvailable: true
			)],
			relativeTo: rootURL
		))
		#expect(requests.map(\.operation) == [
			.discoverProjects,
			.discoverSchemes,
			.discoverSchemes,
			.discoverSchemes,
			.discoverSimulators
		])
		#expect(requests[1].arguments == [
			.init(name: "project.path", value: "/tmp/Fixture/Beta.xcodeproj")
		])
		#expect(requests[3].arguments == [
			.init(name: "workspace.path", value: "/tmp/Fixture/Fixture.xcworkspace")
		])
	}

	// scheme 조회 오류를 변경하지 않고 호출자에게 전달하는지 검증합니다.
	@Test
	func scheme_조회_오류를_보존한다() async {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.timeout"),
			context: .init(command: XcodeBuildMCPOperation.discoverSchemes.rawValue)
		)
		let adapter = XcodeBuildMCPAdapterSpy { request in
			if request.operation == .discoverProjects {
				return projectResult()
			}
			if request.operation == .discoverSchemes {
				return .init(operation: .discoverSchemes, result: .errored(error))
			}

			return unexpectedResult(for: request.operation)
		}
		let provider = XcodeBuildMCPDiscoveryProvider(adapter: adapter)

		await #expect(throws: error) {
			try await provider.discover(at: URL(fileURLWithPath: "/tmp/Fixture"))
		}
	}

	// Simulator 조회 오류를 변경하지 않고 호출자에게 전달하는지 검증합니다.
	@Test
	func Simulator_조회_오류를_보존한다() async {
		let error = RunError(
			kind: .adapter,
			code: .init(rawValue: "adapter.xcodebuildmcp.command.failed"),
			context: .init(command: XcodeBuildMCPOperation.discoverSimulators.rawValue)
		)
		let adapter = XcodeBuildMCPAdapterSpy { request in
			if request.operation == .discoverProjects {
				return emptyProjectResult()
			}
			if request.operation == .discoverSimulators {
				return .init(operation: .discoverSimulators, result: .errored(error))
			}

			return unexpectedResult(for: request.operation)
		}
		let provider = XcodeBuildMCPDiscoveryProvider(adapter: adapter)

		await #expect(throws: error) {
			try await provider.discover(at: URL(fileURLWithPath: "/tmp/Fixture"))
		}
	}

	// project와 workspace 후보 payload를 반환합니다.
	private func projectResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverProjects,
			result: .passed,
			payload: .object([
				"projects": .array([
					.object(["path": .string("Beta.xcodeproj")]),
					.object(["path": .string("Alpha.xcodeproj")])
				]),
				"workspaces": .array([
					.object(["path": .string("Fixture.xcworkspace")])
				])
			])
		)
	}

	// 후보가 없는 project와 workspace payload를 반환합니다.
	private func emptyProjectResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverProjects,
			result: .passed,
			payload: .object([
				"projects": .array([]),
				"workspaces": .array([])
			])
		)
	}

	// 요청 경로에 맞는 scheme payload를 반환합니다.
	private func schemeResult(for request: XcodeBuildMCPRequest) -> XcodeBuildMCPResult {
		let path = request.arguments.first?.value
		let schemes: [String] = switch path {
		case "/tmp/Fixture/Alpha.xcodeproj": ["App"]
		case "/tmp/Fixture/Beta.xcodeproj": ["Library"]
		case "/tmp/Fixture/Fixture.xcworkspace": ["App"]
		default: []
		}

		return .init(
			operation: .discoverSchemes,
			result: .passed,
			payload: .object(["schemes": .array(schemes.map(XcodeBuildMCPPayload.string))])
		)
	}

	// Simulator 후보 payload를 반환합니다.
	private func simulatorResult() -> XcodeBuildMCPResult {
		.init(
			operation: .discoverSimulators,
			result: .passed,
			payload: .object([
				"simulators": .array([
					.object([
						"name": .string("iPhone 17"),
						"simulatorId": .string("simulator-id"),
						"state": .string("Shutdown"),
						"runtime": .string("iOS 26.0"),
						"isAvailable": .boolean(true)
					])
				])
			])
		)
	}

	// 예상하지 않은 operation의 오류 결과를 반환합니다.
	private func unexpectedResult(for operation: XcodeBuildMCPOperation) -> XcodeBuildMCPResult {
		.init(
			operation: operation,
			result: .errored(.init(
				kind: .adapter,
				code: .init(rawValue: "adapter.xcodebuildmcp.unexpected"),
				context: .init(command: operation.rawValue)
			))
		)
	}
}

// 호출 결과와 요청 순서를 기록하는 XcodeBuildMCP adapter 시험 대역입니다.
private actor XcodeBuildMCPAdapterSpy: XcodeBuildMCPAdapter {
	private let resultForRequest: @Sendable (XcodeBuildMCPRequest) -> XcodeBuildMCPResult
	private var receivedRequests: [XcodeBuildMCPRequest] = []

	// 요청별 고정 결과를 반환할 시험 대역을 구성합니다.
	init(resultForRequest: @escaping @Sendable (XcodeBuildMCPRequest) -> XcodeBuildMCPResult) {
		self.resultForRequest = resultForRequest
	}

	// 요청을 기록하고 고정 결과를 반환합니다.
	func execute(_ request: XcodeBuildMCPRequest) async -> XcodeBuildMCPResult {
		receivedRequests.append(request)

		return resultForRequest(request)
	}

	// 사용하지 않는 진행 사건 stream을 반환합니다.
	nonisolated func events(
		for _: XcodeBuildMCPRequest
	) -> AsyncThrowingStream<XcodeBuildMCPEvent, any Error> {
		.init { $0.finish() }
	}

	// 기록된 요청을 반환합니다.
	func requests() -> [XcodeBuildMCPRequest] {
		receivedRequests
	}
}
