//
//  DoctorProcessRunnerSpies.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// 기본 FoundationProcessRunner를 사용하는 doctor reporter를 구성합니다.
func makeReporter(
	workingDirectoryURL: URL = URL(fileURLWithPath: "/tmp"),
	environment: [String: String] = [:]
) -> XcodeBuildMCPDoctorReporter {
	.init(
		workingDirectoryURL: workingDirectoryURL,
		environment: environment,
		timeout: .seconds(5)
	)
}

// 주입한 process runner를 사용하는 doctor reporter를 구성합니다.
func makeReporter(
	processRunner: any ProcessRunning,
	workingDirectoryURL: URL = URL(fileURLWithPath: "/tmp"),
	environment: [String: String] = [:]
) -> XcodeBuildMCPDoctorReporter {
	.init(
		processRunner: processRunner,
		workingDirectoryURL: workingDirectoryURL,
		environment: environment,
		timeout: .seconds(5)
	)
}

// 가짜 xcodebuildmcp 실행 파일을 설치할 임시 디렉터리를 생성합니다.
func makeTemporaryDirectory() throws -> URL {
	let directory = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString, isDirectory: true)
	try FileManager.default.createDirectory(
		at: directory,
		withIntermediateDirectories: true
	)

	return directory
}

// fixture script를 PATH에서 찾을 수 있는 xcodebuildmcp 실행 파일로 설치합니다.
func installFakeXcodeBuildMCP(in directory: URL) throws {
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

// doctor 요청을 기록하고 미리 정한 결과를 순서대로 반환합니다.
actor DoctorProcessRunnerSpy: ProcessRunning {
	private var results: [ProcessResult]
	private var requests = [ProcessRequest]()

	// 반환할 process 결과로 시험 대역을 구성합니다.
	init(results: [ProcessResult]) {
		self.results = results
	}

	// 요청을 기록하고 다음 process 결과를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		requests.append(request)
		return results.removeFirst()
	}

	// 기록한 process 요청을 반환합니다.
	var receivedRequests: [ProcessRequest] {
		requests
	}
}

// version 요청 뒤 timeout을 반환하는 process 실행기입니다.
actor TimeoutProcessRunnerSpy: ProcessRunning {
	private var didReturnVersion = false

	// version 결과를 한 번 반환한 뒤 timeout 오류를 던집니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		if !didReturnVersion {
			didReturnVersion = true

			return .init(
				standardOutput: Data("2.7.0-fixture\n".utf8),
				terminationStatus: 0
			)
		}

		throw ProcessRunnerError.timedOut
	}
}

// 지정한 process 실행 오류를 반환하는 실행기입니다.
struct FailingProcessRunnerSpy: ProcessRunning {
	let error: ProcessRunnerError

	// 지정한 process 실행 오류를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		throw error
	}
}
