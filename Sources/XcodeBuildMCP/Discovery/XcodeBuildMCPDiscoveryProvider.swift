//
//  XcodeBuildMCPDiscoveryProvider.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import QALenzCore

// XcodeBuildMCP 조회 결과를 QALenz discovery 후보로 제공하는 계약입니다.
package protocol XcodeBuildMCPDiscoveryProviding: Sendable {
	// 기준 경로의 실행 대상 후보를 반환합니다.
	func discover(at rootURL: URL) async throws -> DiscoveryResult
}

// XcodeBuildMCP adapter 조회를 DiscoveryResult로 조합합니다.
package struct XcodeBuildMCPDiscoveryProvider: XcodeBuildMCPDiscoveryProviding, Sendable {
	private let adapter: any XcodeBuildMCPAdapter

	// 주입한 adapter로 provider를 구성합니다.
	package init(adapter: any XcodeBuildMCPAdapter) {
		self.adapter = adapter
	}

	// project, workspace, scheme, Simulator 후보를 순서대로 조회합니다.
	package func discover(at rootURL: URL) async throws -> DiscoveryResult {
		let projectResult = await adapter.execute(.init(
			operation: .discoverProjects,
			arguments: [.init(name: "workspace.root", value: rootURL.path)]
		))
		let projectURLs = try fileURLs(
			from: projectResult,
			key: "projects",
			operation: .discoverProjects,
			relativeTo: rootURL
		)
		let workspaceURLs = try fileURLs(
			from: projectResult,
			key: "workspaces",
			operation: .discoverProjects,
			relativeTo: rootURL
		)
		let schemeNames = try await discoverSchemeNames(
			projectURLs: projectURLs,
			workspaceURLs: workspaceURLs
		)
		let simulatorResult = await adapter.execute(.init(operation: .discoverSimulators))
		let simulators = try discoverySimulators(from: simulatorResult)

		return .init(
			projectURLs: projectURLs,
			workspaceURLs: workspaceURLs,
			schemeNames: schemeNames,
			simulators: simulators,
			relativeTo: rootURL
		)
	}

	// project와 workspace 후보별 scheme 이름을 조회합니다.
	private func discoverSchemeNames(
		projectURLs: [URL],
		workspaceURLs: [URL]
	) async throws -> [String] {
		var names: [String] = []

		for projectURL in projectURLs {
			let result = await adapter.execute(.init(
				operation: .discoverSchemes,
				arguments: [.init(name: "project.path", value: projectURL.path)]
			))
			names += try strings(
				from: result,
				key: "schemes",
				operation: .discoverSchemes
			)
		}

		for workspaceURL in workspaceURLs {
			let result = await adapter.execute(.init(
				operation: .discoverSchemes,
				arguments: [.init(name: "workspace.path", value: workspaceURL.path)]
			))
			names += try strings(
				from: result,
				key: "schemes",
				operation: .discoverSchemes
			)
		}

		return names
	}

	// project 또는 workspace payload의 path 값을 file URL로 변환합니다.
	private func fileURLs(
		from result: XcodeBuildMCPResult,
		key: String,
		operation: XcodeBuildMCPOperation,
		relativeTo rootURL: URL
	) throws -> [URL] {
		let payload = try payload(from: result, operation: operation)
		guard
			case let .object(values) = payload,
			case let .array(entries) = values[key]
		else {
			throw failureError(for: operation, reason: .invalidPayload)
		}

		return try entries.map {
			guard case let .object(values) = $0,
				case let .string(path) = values["path"]
			else {
				throw failureError(for: operation, reason: .invalidPayload)
			}

			return fileURL(for: path, relativeTo: rootURL)
		}
	}

	// 문자열 배열 payload를 반환하고 adapter 오류를 보존합니다.
	private func strings(
		from result: XcodeBuildMCPResult,
		key: String,
		operation: XcodeBuildMCPOperation
	) throws -> [String] {
		let payload = try payload(from: result, operation: operation)
		guard
			case let .object(values) = payload,
			case let .array(entries) = values[key]
		else {
			throw failureError(for: operation, reason: .invalidPayload)
		}

		return try entries.map {
			guard case let .string(value) = $0 else {
				throw failureError(for: operation, reason: .invalidPayload)
			}

			return value
		}
	}

	// Simulator payload를 Core 후보로 변환합니다.
	private func discoverySimulators(
		from result: XcodeBuildMCPResult
	) throws -> [DiscoverySimulator] {
		let payload = try payload(from: result, operation: .discoverSimulators)
		guard
			case let .object(values) = payload,
			case let .array(entries) = values["simulators"]
		else {
			throw failureError(for: .discoverSimulators, reason: .invalidPayload)
		}

		return try entries.map(discoverySimulator)
	}

	// 단일 Simulator payload를 Core 후보로 변환합니다.
	private func discoverySimulator(
		from payload: XcodeBuildMCPPayload
	) throws -> DiscoverySimulator {
		guard case let .object(values) = payload,
			case let .string(name) = values["name"],
			case let .string(simulatorId) = values["simulatorId"],
			case let .string(state) = values["state"],
			case let .string(runtime) = values["runtime"],
			case let .boolean(isAvailable) = values["isAvailable"]
		else {
			throw failureError(for: .discoverSimulators, reason: .invalidPayload)
		}

		return .init(
			name: name,
			simulatorId: simulatorId,
			state: state,
			runtime: runtime,
			isAvailable: isAvailable
		)
	}

	// 성공 payload를 반환하거나 adapter가 전달한 오류를 그대로 반환합니다.
	private func payload(
		from result: XcodeBuildMCPResult,
		operation: XcodeBuildMCPOperation
	) throws -> XcodeBuildMCPPayload {
		guard result.operation == operation else {
			throw failureError(for: operation, reason: .invalidPayload)
		}

		switch result.result {
		case .passed:
			guard let payload = result.payload else {
				throw failureError(for: operation, reason: .invalidPayload)
			}

			return payload
		case .failed:
			throw failureError(for: operation, reason: .failedResult)
		case let .errored(error):
			throw error
		}
	}

	// 반환된 경로를 기준 경로 기준의 file URL로 변환합니다.
	private func fileURL(for path: String, relativeTo rootURL: URL) -> URL {
		guard !path.hasPrefix("/") else {
			return URL(fileURLWithPath: path).standardizedFileURL
		}

		return rootURL.appendingPathComponent(path).standardizedFileURL
	}

	// provider가 구분할 adapter 실패 원인을 나타냅니다.
	private enum FailureReason {
		case invalidPayload
		case failedResult
	}

	// 실패 원인에 맞는 adapter 오류를 구성합니다.
	private func failureError(
		for operation: XcodeBuildMCPOperation,
		reason: FailureReason
	) -> RunError {
		let code = switch reason {
		case .invalidPayload:
			"adapter.xcodebuildmcp.output.invalid"
		case .failedResult:
			"adapter.xcodebuildmcp.command.failed"
		}

		return .init(
			kind: .adapter,
			code: .init(rawValue: code),
			context: .init(command: operation.rawValue)
		)
	}
}
