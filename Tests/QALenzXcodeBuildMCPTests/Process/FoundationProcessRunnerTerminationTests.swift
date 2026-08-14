//
//  FoundationProcessRunnerTerminationTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Darwin
import Foundation
import Testing
@testable import QALenzXcodeBuildMCP

// FoundationProcessRunner의 정상 종료 stdout 처리를 검증합니다.
@Suite
struct FoundationProcessRunnerTerminationTests {
	// stdout 작성자가 열린 상태에서도 현재 buffer만 회수하는지 검증합니다.
	@Test
	func stdout_작성자가_열린_상태에서도_현재_buffer만_회수한다() throws {
		let output = Pipe()
		defer { try? output.fileHandleForReading.close() }
		defer { try? output.fileHandleForWriting.close() }
		let expected = Data("buffered-before-termination".utf8)
		try output.fileHandleForWriting.write(contentsOf: expected)
		let start = Date()

		let data = StandardOutputDrainer.drainBufferedData(from: output.fileHandleForReading)

		#expect(Date().timeIntervalSince(start) < 0.5)
		#expect(data == expected)
	}

	// 정상 종료한 process의 하위 process가 stdout을 유지해도 단일 실행이 종료하는지 검증합니다.
	@Test
	func 정상_종료_뒤_하위_process가_stdout을_유지해도_단일_실행이_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let pidURL = directory.appendingPathComponent("child.pid")
		defer { terminateProcess(at: pidURL) }
		let executableURL = try makeStandardOutputHoldingChildExecutable(
			in: directory,
			pidURL: pidURL
		)
		let runner = FoundationProcessRunner()

		let result = try await runner.run(.init(
			executableURL: executableURL,
			arguments: [],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(5)
		))

		#expect(isProcessRunning(at: pidURL))
		#expect(result.terminationStatus == 0)
		#expect(result.standardOutput == Data("received-before-termination".utf8))
	}

	// 정상 종료한 process의 하위 process가 stdout을 유지해도 사건 stream이 순서대로 종료하는지 검증합니다.
	@Test
	func 정상_종료_뒤_하위_process가_stdout을_유지해도_사건_stream이_순서대로_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let pidURL = directory.appendingPathComponent("child.pid")
		defer { terminateProcess(at: pidURL) }
		let executableURL = try makeStandardOutputHoldingChildExecutable(
			in: directory,
			pidURL: pidURL
		)
		let runner = FoundationProcessRunner()
		var events = [ProcessEvent]()

		for try await event in runner.events(for: .init(
			executableURL: executableURL,
			arguments: [],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(5)
		)) {
			events.append(event)
		}

		let standardOutput = events.reduce(into: Data()) { data, event in
			guard case let .standardOutput(chunk) = event else { return }
			data.append(chunk)
		}
		let terminationStatuses = events.compactMap { event -> Int32? in
			guard case let .terminated(status) = event else { return nil }
			return status
		}
		let terminationIndex = try #require(events.firstIndex { event in
			if case .terminated = event {
				return true
			}
			return false
		})
		let hasOutputAfterTermination = events.indices.contains { index in
			guard terminationIndex < index else { return false }
			guard case .standardOutput = events[index] else { return false }
			return true
		}

		#expect(isProcessRunning(at: pidURL))
		#expect(standardOutput == Data("received-before-termination".utf8))
		#expect(terminationStatuses == [0])
		#expect(!hasOutputAfterTermination)
	}

	// 시험 전용 임시 디렉터리를 생성합니다.
	private func makeTemporaryDirectory() throws -> URL {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)

		return directory
	}

	// 제어된 shell script 가짜 실행 파일을 생성합니다.
	private func makeExecutable(in directory: URL, script: String) throws -> URL {
		let executableURL = directory.appendingPathComponent("fixture")
		try script.write(to: executableURL, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes(
			[.posixPermissions: 0o755],
			ofItemAtPath: executableURL.path
		)

		return executableURL
	}

	// 직접 process 종료 뒤에도 stdout pipe를 유지하는 가짜 실행 파일을 생성합니다.
	private func makeStandardOutputHoldingChildExecutable(
		in directory: URL,
		pidURL: URL
	) throws -> URL {
		try makeExecutable(
			in: directory,
			script: """
			#!/bin/sh
			/bin/sh -c 'exec /bin/sleep 10' &
			printf '%s' "$!" > "\(pidURL.path)"
			printf '%s' 'received-before-termination'
			"""
		)
	}

	// PID 파일이 가리키는 하위 process의 실행 상태를 반환합니다.
	private func isProcessRunning(at url: URL) -> Bool {
		guard
			let contents = try? String(contentsOf: url, encoding: .utf8),
			let pid = Int32(contents)
		else { return false }

		return kill(pid, 0) == 0
	}

	// PID 파일이 가리키는 하위 process를 정리합니다.
	private func terminateProcess(at url: URL) {
		guard
			let contents = try? String(contentsOf: url, encoding: .utf8),
			let pid = Int32(contents)
		else { return }

		_ = kill(pid, SIGKILL)
	}
}
