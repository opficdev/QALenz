//
//  XcodeBuildMCPCLIAdapterEventTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPCLIAdapter의 JSONL 사건 전달 시점을 검증합니다.
@Suite
struct XcodeBuildMCPCLIAdapterEventTests {
	private let buildSimulatorOperation = XcodeBuildMCPOperation(rawValue: "build.simulator")

	// JSONL 사건이 process 종료 전에 공통 진행 사건으로 전달되는지 검증합니다.
	@Test
	func JSONL_사건이_process_종료_전에_전달된다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path],
			timeout: .seconds(5)
		)
		let handshakeURL = directory.appendingPathComponent("stream-received")
		let stream = adapter.events(for: .init(
			operation: buildSimulatorOperation,
			arguments: [
				.init(name: "scheme.name", value: "streaming"),
				.init(name: "project.path", value: handshakeURL.path)
			]
		))
		var iterator = stream.makeAsyncIterator()

		let started = try await iterator.next()
		try Data().write(to: handshakeURL)
		let completed = try await iterator.next()

		#expect(started?.kind == .started)
		#expect(completed?.kind == .completed)
		#expect(try await iterator.next() == nil)
	}

	// 가짜 xcodebuildmcp 실행 파일을 설치할 임시 디렉터리를 생성합니다.
	private func makeTemporaryDirectory() throws -> URL {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)

		return directory
	}

	// fixture script를 PATH에서 찾을 수 있는 xcodebuildmcp 실행 파일로 설치합니다.
	private func installFakeXcodeBuildMCP(in directory: URL) throws {
		let fixtureURL = try #require(
			Bundle.module.url(forResource: "fake-xcodebuildmcp", withExtension: nil)
		)
		let executableURL = directory.appendingPathComponent("xcodebuildmcp")

		try FileManager.default.copyItem(at: fixtureURL, to: executableURL)
		try FileManager.default.setAttributes(
			[.posixPermissions: 0o755],
			ofItemAtPath: executableURL.path
		)
	}
}
