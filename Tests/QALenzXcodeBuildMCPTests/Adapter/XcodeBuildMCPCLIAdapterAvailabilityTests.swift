//
//  XcodeBuildMCPCLIAdapterAvailabilityTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCPCLIAdapter의 CLI 사용 가능 상태 정규화를 검증합니다.
@Suite
struct XcodeBuildMCPCLIAdapterAvailabilityTests {
	private let buildSimulatorOperation = XcodeBuildMCPOperation(rawValue: "build.simulator")
	private let discoverSimulatorsOperation = XcodeBuildMCPOperation(rawValue: "discover.simulators")

	// 설치되지 않은 CLI의 일반 실행 결과가 unavailable 오류인지 검증합니다.
	@Test
	func 설치되지_않은_CLI의_일반_실행이_unavailable로_정규화된다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let adapter = makeAdapter(workingDirectoryURL: directory)

		let result = await adapter.execute(.init(operation: discoverSimulatorsOperation))
		let error = try runError(from: result)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.unavailable")
	}

	// 설치되지 않은 CLI의 사건 실행 결과가 unavailable 오류인지 검증합니다.
	@Test
	func 설치되지_않은_CLI의_사건_실행이_unavailable로_정규화된다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let adapter = makeAdapter(workingDirectoryURL: directory)

		do {
			for try await _ in adapter.events(for: .init(operation: buildSimulatorOperation)) {}
			Issue.record("unavailable 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.unavailable")
		}
	}

	// 잘못된 working directory의 일반 실행이 process 실패 오류로 정규화되는지 검증합니다.
	@Test
	func 잘못된_작업_경로의_일반_실행이_process_실패로_정규화된다() async throws {
		let adapter = makeAdapter(workingDirectoryURL: makeMissingDirectoryURL())

		let result = await adapter.execute(.init(operation: discoverSimulatorsOperation))
		let error = try runError(from: result)

		#expect(error.code.rawValue == "adapter.xcodebuildmcp.process.failed")
	}

	// 잘못된 working directory의 사건 실행이 process 실패 오류로 정규화되는지 검증합니다.
	@Test
	func 잘못된_작업_경로의_사건_실행이_process_실패로_정규화된다() async throws {
		let adapter = makeAdapter(workingDirectoryURL: makeMissingDirectoryURL())

		do {
			for try await _ in adapter.events(for: .init(operation: buildSimulatorOperation)) {}
			Issue.record("process 실패 오류가 반환되지 않음")
		} catch let error as RunError {
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.process.failed")
		}
	}

	// 지정한 작업 경로와 CLI가 없는 PATH를 사용하는 adapter를 생성합니다.
	private func makeAdapter(workingDirectoryURL: URL) -> XcodeBuildMCPCLIAdapter {
		.init(
			workingDirectoryURL: workingDirectoryURL,
			environment: ["PATH": workingDirectoryURL.path],
			timeout: .seconds(1)
		)
	}

	// 존재하지 않는 시험 전용 작업 경로를 생성합니다.
	private func makeMissingDirectoryURL() -> URL {
		FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
	}

	// 실행 결과에서 정규화된 오류를 꺼냅니다.
	private func runError(from result: XcodeBuildMCPResult) throws -> RunError {
		guard case let .errored(error) = result.result else {
			Issue.record("오류 실행 결과가 반환되지 않음")
			throw TestError.missingRunError
		}

		return error
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
}

// 시험 보조 함수에서 발생한 필수 값 누락을 표현합니다.
private enum TestError: Error {
	case missingRunError
}
