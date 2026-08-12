//
//  FoundationXcodeBuildMCPProcessRunnerTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation
import Testing
@testable import QALenzXcodeBuildMCP

@Suite(.serialized)
struct FoundationProcessRunnerTests {
	@Test
	func 시험용_실행_파일이_지정한_작업_경로에서_실행된다() async throws {
		let directory = FileManager.default.temporaryDirectory
		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "working-directory"],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(1),
			terminationGracePeriod: .milliseconds(50)
		)

		let response = try await FoundationXcodeBuildMCPProcessRunner().run(
			request
		)

		#expect(response.terminationStatus == 0)
		let path = try #require(
			String(data: response.standardOutput, encoding: .utf8)
		)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let actual = URL(fileURLWithPath: path).resolvingSymlinksInPath()
		let expected = directory.resolvingSymlinksInPath()

		#expect(actual == expected)
	}

	@Test
	func 표준_출력_이벤트가_프로세스_종료_전에_전달된다() async throws {
		let directory = FileManager.default.temporaryDirectory
			.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		let signal = directory.appending(path: "continue")
		try FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)
		defer { try? FileManager.default.removeItem(at: directory) }

		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "streaming", signal.path()],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(1),
			terminationGracePeriod: .milliseconds(50)
		)
		let stream = FoundationXcodeBuildMCPProcessRunner().events(for: request)
		var iterator = stream.makeAsyncIterator()
		let first = try #require(await iterator.next())

		guard case let .standardOutput(data) = first else {
			Issue.record("첫 번째 process 사건이 stdout이 아님")
			return
		}
		let line = try #require(String(data: data, encoding: .utf8))

		#expect(line.contains("invocation"))

		try Data().write(to: signal)

		var status: Int32?
		while let event = try await iterator.next() {
			if case let .terminated(value) = event {
				status = value
			}
		}

		#expect(status == 0)
	}

	@Test
	func 종료_신호를_무시하는_프로세스가_시간_초과_후_강제_종료된다() async {
		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "ignore-term"],
			workingDirectoryURL: FileManager.default.temporaryDirectory,
			environment: [:],
			timeout: .milliseconds(50),
			terminationGracePeriod: .milliseconds(50)
		)

		await #expect(throws: XcodeBuildMCPProcessError.timedOut) {
			try await FoundationXcodeBuildMCPProcessRunner().run(request)
		}
	}

	@Test
	func 최대_크기를_초과한_stdout이_process를_종료한다() async {
		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "excessive-stdout"],
			workingDirectoryURL: FileManager.default.temporaryDirectory,
			environment: [:],
			timeout: .seconds(5),
			terminationGracePeriod: .milliseconds(50),
			maximumStandardOutputByteCount: 32
		)
		let clock = ContinuousClock()
		let start = clock.now

		await #expect(
			throws: XcodeBuildMCPProcessError.standardOutputLimitExceeded
		) {
			try await FoundationXcodeBuildMCPProcessRunner().run(request)
		}

		#expect(start.duration(to: clock.now) < .milliseconds(500))
	}

	@Test
	func 시간_초과가_전체_하위_프로세스_트리를_종료한다() async throws {
		let directory = FileManager.default.temporaryDirectory
			.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		let pidURL = directory.appending(path: "child.pid")
		try? FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)
		defer { try? FileManager.default.removeItem(at: directory) }

		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "child-tree", pidURL.path()],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .milliseconds(50),
			terminationGracePeriod: .milliseconds(50)
		)
		let cleanupTask = Task.detached {
			try? await Task.sleep(for: .seconds(1))
			guard
				let value = try? String(contentsOf: pidURL, encoding: .utf8),
				let pid = Int32(value.trimmingCharacters(in: .whitespacesAndNewlines))
			else { return }

			Darwin.kill(pid, SIGKILL)
		}
		let clock = ContinuousClock()
		let start = clock.now

		await #expect(throws: XcodeBuildMCPProcessError.timedOut) {
			try await FoundationXcodeBuildMCPProcessRunner().run(request)
		}

		let elapsed = start.duration(to: clock.now)
		cleanupTask.cancel()
		_ = await cleanupTask.result
		let value = try String(contentsOf: pidURL, encoding: .utf8)
		let pid = try #require(
			Int32(value.trimmingCharacters(in: .whitespacesAndNewlines))
		)
		let isRunning = Darwin.kill(pid, 0) == 0
		if isRunning {
			Darwin.kill(pid, SIGKILL)
		}

		#expect(elapsed < .milliseconds(500))
		#expect(!isRunning)
	}

	@Test
	func 실행_작업을_취소하면_자식_프로세스가_종료되고_취소_오류가_반환된다() async {
		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "sleep"],
			workingDirectoryURL: FileManager.default.temporaryDirectory,
			environment: [:],
			timeout: .seconds(5),
			terminationGracePeriod: .milliseconds(50)
		)
		let task = Task {
			try await FoundationXcodeBuildMCPProcessRunner().run(request)
		}

		try? await Task.sleep(for: .milliseconds(50))
		task.cancel()

		await #expect(throws: XcodeBuildMCPProcessError.cancelled) {
			try await task.value
		}
	}

	@Test
	func 즉시_취소된_요청은_프로세스를_시작하지_않는다() async {
		let directory = FileManager.default.temporaryDirectory
			.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		let markerURL = directory.appending(path: "launched")
		try? FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)
		defer { try? FileManager.default.removeItem(at: directory) }

		let request = XcodeBuildMCPProcessRequest(
			executableURL: fakeExecutableURL,
			arguments: ["fixture", "launch-marker", markerURL.path()],
			workingDirectoryURL: directory,
			environment: [:],
			timeout: .seconds(5),
			terminationGracePeriod: .milliseconds(50)
		)
		let task = Task {
			try? await Task.sleep(for: .seconds(1))
			let stream = FoundationXcodeBuildMCPProcessRunner().events(for: request)
			for try await _ in stream {}
		}

		task.cancel()
		_ = await task.result
		try? await Task.sleep(for: .milliseconds(50))

		#expect(!FileManager.default.fileExists(atPath: markerURL.path()))
	}

	@Test
	func 허용_목록의_환경_변수만_남는다() {
		let filter = XcodeBuildMCPEnvironmentFilter()
		let environment = filter.apply(to: [
			"PATH": "/usr/bin",
			"HOME": "/tmp/home",
			"TMPDIR": "/tmp",
			"DEVELOPER_DIR": "/Applications/Xcode.app",
			"XCODEBUILDMCP_CWD": "/tmp/project",
			"SECRET_TOKEN": "secret-token-value"
		])

		#expect(environment == [
			"PATH": "/usr/bin",
			"HOME": "/tmp/home",
			"TMPDIR": "/tmp",
			"DEVELOPER_DIR": "/Applications/Xcode.app",
			"XCODEBUILDMCP_CWD": "/tmp/project"
		])
	}

	private var fakeExecutableURL: URL {
		Bundle.module.url(
			forResource: "fake-xcodebuildmcp",
			withExtension: nil,
			subdirectory: "Fixtures"
		)!
	}
}
