//
//  FoundationProcessRunnerTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Darwin
import Foundation
import Testing
@testable import QALenzXcodeBuildMCP

// FoundationProcessRunner의 실행 경계와 종료 처리를 검증합니다.
@Suite
struct FoundationProcessRunnerTests {
	// 가짜 실행 파일이 working directory와 허용된 환경만 받는지 검증합니다.
	@Test
	func 가짜_실행_파일이_작업_경로와_허용된_환경을_받는다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = try makeExecutable(
			in: directory,
			script: "#!/bin/sh\nprintf '%s|%s|%s' \"$PWD\" \"$VISIBLE\" \"$HIDDEN\""
		)
		let runner = FoundationProcessRunner()

		let result = try await runner.run(.init(
			executableURL: executableURL,
			arguments: [],
			workingDirectoryURL: directory,
			environment: ["VISIBLE": "allowed"],
			timeout: .seconds(5)
		))

		#expect(result.terminationStatus == 0)
		let output = try #require(String(bytes: result.standardOutput, encoding: .utf8))
		let values = output
			.split(separator: "|", omittingEmptySubsequences: false)

		#expect(values[0].hasSuffix(directory.lastPathComponent))
		#expect(values[1] == "allowed")
		#expect(values[2].isEmpty)
	}

	// 시간 제한이 지나면 가짜 실행 파일을 종료하는지 검증합니다.
	@Test
	func 시간_제한이_지나면_가짜_실행_파일을_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = try makeExecutable(
			in: directory,
			script: "#!/bin/sh\nexec /bin/sleep 10"
		)
		let runner = FoundationProcessRunner()
		let start = Date()

		do {
			_ = try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: directory,
				environment: [:],
				timeout: .milliseconds(50)
			))
			Issue.record("시간 제한 오류가 반환되지 않음")
		} catch let error as ProcessRunnerError {
			#expect(error == .timedOut)
		}

		#expect(Date().timeIntervalSince(start) < 5)
	}

	// 시간 제한 오류가 하위 process의 stdout EOF를 기다리지 않고 반환되는지 검증합니다.
	@Test
	func 시간_제한_경로가_하위_process의_stdout_EOF를_기다리지_않는다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let pidURL = directory.appendingPathComponent("child.pid")
		defer { terminateProcess(at: pidURL) }
		let executableURL = try makeExecutable(
			in: directory,
			script: """
			#!/bin/sh
			/bin/sh -c 'trap "" TERM; /bin/sleep 3' &
			printf '%s' "$!" > "\(pidURL.path)"
			wait
			"""
		)
		let runner = FoundationProcessRunner()
		let start = Date()

		do {
			_ = try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: directory,
				environment: [:],
				timeout: .milliseconds(500)
			))
			Issue.record("시간 제한 오류가 반환되지 않음")
		} catch let error as ProcessRunnerError {
			#expect(error == .timedOut)
		}

		#expect(Date().timeIntervalSince(start) < 1.5)
	}

	// 존재하지 않는 실행 파일이 사용 가능하지 않음 오류로 구분되는지 검증합니다.
	@Test
	func 존재하지_않는_실행_파일이_사용_가능하지_않음_오류로_구분된다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = directory.appendingPathComponent("missing-executable")
		let runner = FoundationProcessRunner()

		do {
			_ = try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: directory,
				environment: [:],
				timeout: .seconds(5)
			))
			Issue.record("실행 파일 오류가 반환되지 않음")
		} catch let error as ProcessRunnerError {
			#expect(error == .executableUnavailable)
		}
	}

	// 존재하지 않는 working directory가 별도 오류로 구분되는지 검증합니다.
	@Test
	func 존재하지_않는_작업_경로가_별도_오류로_구분된다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = try makeExecutable(in: directory, script: "#!/bin/sh\nexit 0")
		let workingDirectoryURL = directory.appendingPathComponent("missing-directory")
		let runner = FoundationProcessRunner()

		do {
			_ = try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: workingDirectoryURL,
				environment: [:],
				timeout: .seconds(5)
			))
			Issue.record("작업 경로 오류가 반환되지 않음")
		} catch let error as ProcessRunnerError {
			#expect(error == .invalidWorkingDirectory)
		}
	}

	// 종료 요청을 무시하는 가짜 실행 파일도 유예 시간 뒤 강제 종료하는지 검증합니다.
	@Test
	func 종료_요청을_무시하면_유예_시간_뒤_강제_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = try makeExecutable(
			in: directory,
			script: """
			#!/usr/bin/python3
			import os
			import signal
			import threading

			signal.signal(signal.SIGTERM, signal.SIG_IGN)
			threading.Timer(10, lambda: os.kill(os.getpid(), signal.SIGKILL)).start()
			threading.Event().wait()
			"""
		)
		let runner = FoundationProcessRunner()
		let start = Date()

		do {
			_ = try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: directory,
				environment: [:],
				timeout: .milliseconds(500)
			))
			Issue.record("시간 제한 오류가 반환되지 않음")
		} catch let error as ProcessRunnerError {
			#expect(error == .timedOut)
		}

		#expect(Date().timeIntervalSince(start) < 5)
	}

	// 취소된 실행이 가짜 실행 파일을 종료하는지 검증합니다.
	@Test
	func 취소된_실행이_가짜_실행_파일을_종료한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let executableURL = try makeExecutable(
			in: directory,
			script: "#!/bin/sh\nexec /bin/sleep 10"
		)
		let runner = FoundationProcessRunner()
		let task = Task {
			try await runner.run(.init(
				executableURL: executableURL,
				arguments: [],
				workingDirectoryURL: directory,
				environment: [:],
				timeout: .seconds(10)
			))
		}

		try await Task.sleep(for: .milliseconds(50))
		task.cancel()

		do {
			_ = try await task.value
			Issue.record("취소 오류가 반환되지 않음")
		} catch is CancellationError {}
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

	// PID 파일이 가리키는 하위 process를 정리합니다.
	private func terminateProcess(at url: URL) {
		guard
			let contents = try? String(contentsOf: url, encoding: .utf8),
			let pid = Int32(contents)
		else { return }

		_ = kill(pid, SIGKILL)
	}
}
