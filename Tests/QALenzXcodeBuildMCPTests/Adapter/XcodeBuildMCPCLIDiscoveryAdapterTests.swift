//
//  XcodeBuildMCPCLIDiscoveryAdapterTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPCLIAdapter의 discovery 출력 정규화를 검증합니다.
@Suite
struct XcodeBuildMCPCLIDiscoveryAdapterTests {
	// 기본 registry가 project와 workspace 후보 JSON 결과를 정규화하는지 검증합니다.
	@Test
	func 기본_registry가_project와_workspace_후보_JSON_결과를_정규화한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)

		let result = await adapter.execute(.init(
			operation: .discoverProjects,
			arguments: [.init(name: "workspace.root", value: directory.path)]
		))

		#expect(result.result == .passed)
		#expect(result.payload == .object([
			"projects": .array([
				.object(["path": .string("/tmp/Fixture.xcodeproj")])
			]),
			"workspaces": .array([
				.object(["path": .string("/tmp/Fixture.xcworkspace")])
			])
		]))
		#expect(!adapter.supportsEvents(for: .discoverProjects))
	}

	// 기본 registry가 scheme 목록 JSON 결과를 정규화하는지 검증합니다.
	@Test
	func 기본_registry가_scheme_목록_JSON_결과를_정규화한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)

		let result = await adapter.execute(.init(
			operation: .discoverSchemes,
			arguments: [.init(name: "project.path", value: "/tmp/Fixture.xcodeproj")]
		))

		#expect(result.result == .passed)
		#expect(result.payload == .object([
			"schemes": .array([.string("Fixture")])
		]))
		#expect(!adapter.supportsEvents(for: .discoverSchemes))
	}
}
