//
//  FoundationProcessRunnerBackpressureTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Darwin
import Foundation
import Testing
@testable import QALenzXcodeBuildMCP

// FoundationProcessRunner의 표준 출력 역압 처리를 검증합니다.
@Suite
struct FoundationProcessRunnerBackpressureTests {
	// 느린 소비자가 표준 출력 조각을 읽을 때 하위 process를 대기시키고 모든 출력을 전달하는지 검증합니다.
	@Test
	func 느린_소비자가_대량_stdout을_유실_없이_순서대로_받는다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let startedURL = directory.appendingPathComponent("started")
		let completedURL = directory.appendingPathComponent("completed")
		let executableURL = try makeExecutable(
			in: directory,
			script: """
			#!/usr/bin/python3
			from pathlib import Path
			import sys

			Path("started").write_text("started")
			sys.stdout.buffer.write(b"x" * (2 * 1024 * 1024))
			sys.stdout.flush()
			Path("completed").write_text("completed")
			"""
		)
		let runner = FoundationProcessRunner(maximumBufferedStandardOutputChunkCount: 1)
		let stream = runner.events(for: .init(
			executableURL: executableURL,
			arguments: [],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(5)
		))

		try await waitForFile(at: startedURL)

		// stdout writer가 제한된 대기열과 Pipe를 채울 시간을 부여합니다.
		try await Task.sleep(for: .milliseconds(50))
		#expect(!FileManager.default.fileExists(atPath: completedURL.path))

		var standardOutput = Data()
		var terminationStatuses = [Int32]()
		var didTerminate = false
		var hasOutputAfterTermination = false

		for try await event in stream {
			switch event {
			case let .standardOutput(data):
				hasOutputAfterTermination = hasOutputAfterTermination || didTerminate
				standardOutput.append(data)
			case let .terminated(status):
				didTerminate = true
				terminationStatuses.append(status)
			}
		}

		#expect(FileManager.default.fileExists(atPath: completedURL.path))
		#expect(standardOutput.count == 2 * 1024 * 1024)
		#expect(terminationStatuses == [0])
		#expect(!hasOutputAfterTermination)
	}

	// 사건 stream 소비를 취소하면 실행 중인 하위 process를 종료하는지 검증합니다.
	@Test
	func 사건_stream_소비를_취소하면_하위_process를_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let pidURL = directory.appendingPathComponent("process.pid")
		let executableURL = try makeExecutable(
			in: directory,
			script: """
			#!/bin/sh
			printf '%s' "$$" > "process.pid"
			exec /bin/sleep 10
			"""
		)
		let runner = FoundationProcessRunner()
		let stream = runner.events(for: .init(
			executableURL: executableURL,
			arguments: [],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(10)
		))
		let task = Task {
			var iterator = stream.makeAsyncIterator()
			return try await iterator.next()
		}

		try await waitForFile(at: pidURL)
		task.cancel()

		do {
			_ = try await task.value
			Issue.record("취소 오류가 반환되지 않음")
		} catch is CancellationError {}

		let pid = try #require(Int32(String(contentsOf: pidURL, encoding: .utf8)))
		try await waitForProcessToExit(pid)
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

	// 지정한 파일이 생성될 때까지 조건을 확인합니다.
	private func waitForFile(at url: URL) async throws {
		let clock = ContinuousClock()
		let deadline = clock.now + .seconds(5)

		while !FileManager.default.fileExists(atPath: url.path) {
			guard clock.now < deadline else {
				Issue.record("실행 시작 표식을 기다리는 시간이 지남")
				return
			}

			try await Task.sleep(for: .milliseconds(10))
		}
	}

	// 지정한 process가 종료될 때까지 조건을 확인합니다.
	private func waitForProcessToExit(_ pid: Int32) async throws {
		let clock = ContinuousClock()
		let deadline = clock.now + .seconds(5)

		while kill(pid, 0) == 0 {
			guard clock.now < deadline else {
				Issue.record("취소한 하위 process의 종료 시간이 지남")
				return
			}

			try await Task.sleep(for: .milliseconds(10))
		}
	}
}
