//
//  SystemDoctorEnvironmentProviderTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// 시스템 환경 진단의 정규화와 process 요청을 검증합니다.
@Suite
struct SystemDoctorEnvironmentProviderTests {
	// Xcode와 Swift version 출력을 환경 진단 항목으로 변환하는지 검증합니다.
	@Test
	func Xcode와_Swift_version_출력을_환경_진단_항목으로_변환한다() async throws {
		let runner = SystemDoctorProcessRunnerSpy(results: [
			.init(
				standardOutput: Data("Xcode 26.6\nBuild version 17F113\n".utf8),
				terminationStatus: 0
			),
			.init(
				standardOutput: Data("Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)\n".utf8),
				terminationStatus: 0
			)
		])
		let provider = makeProvider(
			processRunner: runner,
			environment: [
				"PATH": "/fixture/bin",
				"SECRET": "secret-token-value"
			]
		)

		let result = await provider.diagnoseEnvironment()
		let diagnostics = result.diagnostics
		let requests = await runner.sentRequests()

		#expect(result.error == nil)
		#expect(diagnostics.map(\.id.rawValue) == ["macos", "xcode", "swift"])
		#expect(diagnostics.map(\.status) == [.available, .available, .available])
		#expect(diagnostics[1].message == "Xcode 26.6")
		#expect(diagnostics[2].message == "Swift 6.3.3")
		#expect(requests.map(\.executableURL.path) == [
			"/usr/bin/xcodebuild",
			"/usr/bin/xcrun"
		])
		#expect(requests.map(\.arguments) == [
			["-version"],
			["swift", "--version"]
		])
		#expect(requests.allSatisfy { $0.environment == ["PATH": "/fixture/bin"] })
	}

	// 실행할 수 없는 환경 도구가 누락 상태와 수정 안내로 변환되는지 검증합니다.
	@Test
	func 실행할_수_없는_환경_도구를_누락_진단으로_변환한다() async throws {
		let runner = SystemDoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data(), terminationStatus: 1),
			.init(standardOutput: Data(), terminationStatus: 1)
		])
		let provider = makeProvider(processRunner: runner)

		let result = await provider.diagnoseEnvironment()
		let diagnostics = result.diagnostics

		#expect(result.error == nil)
		#expect(diagnostics.map(\.status) == [.available, .missing, .missing])
		#expect(diagnostics[1].recommendation == "Xcode를 설치하거나 xcode-select로 사용할 Xcode를 선택합니다.")
		#expect(diagnostics[2].recommendation == "Xcode를 설치하거나 xcode-select로 사용할 Xcode를 선택합니다.")
	}

	// 해석할 수 없는 version 원문을 노출하지 않는지 검증합니다.
	@Test
	func 해석할_수_없는_version_원문을_진단에_포함하지_않는다() async throws {
		let runner = SystemDoctorProcessRunnerSpy(results: [
			.init(
				standardOutput: Data("Xcode secret-token-value\n".utf8),
				terminationStatus: 0
			),
			.init(
				standardOutput: Data("Apple Swift version secret-token-value\n".utf8),
				terminationStatus: 0
			)
		])
		let provider = makeProvider(processRunner: runner)

		let result = await provider.diagnoseEnvironment()
		let diagnostics = result.diagnostics

		#expect(result.error == nil)
		#expect(diagnostics.map(\.status) == [.available, .unsupported, .unsupported])
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// 환경 도구 실행 시간 초과에도 macOS 진단을 보존하는지 검증합니다.
	@Test
	func 환경_도구_실행_시간_초과에도_macos_진단을_보존한다() async throws {
		let provider = makeProvider(
			processRunner: FailingSystemDoctorProcessRunnerSpy(error: .timedOut)
		)
		let result = await provider.diagnoseEnvironment()
		let error = try #require(result.error)

		#expect(result.diagnostics.map(\.id.rawValue) == ["macos"])
		#expect(error.kind == .execution)
		#expect(error.code.rawValue == "execution.timeout")
	}

	// Swift 실행 시간 초과에도 앞선 Xcode 진단을 보존하는지 검증합니다.
	@Test
	func Swift_실행_시간_초과에도_Xcode_진단을_보존한다() async throws {
		let provider = makeProvider(
			processRunner: SwiftFailingSystemDoctorProcessRunnerSpy()
		)
		let result = await provider.diagnoseEnvironment()
		let error = try #require(result.error)

		#expect(result.diagnostics.map(\.id.rawValue) == ["macos", "xcode"])
		#expect(result.diagnostics.map(\.status) == [.available, .available])
		#expect(error.kind == .execution)
		#expect(error.code.rawValue == "execution.timeout")
	}

	// 시험용 제공자를 가짜 process 실행기로 구성합니다.
	private func makeProvider(
		processRunner: any ProcessRunning,
		environment: [String: String] = [:]
	) -> SystemDoctorEnvironmentProvider {
		.init(
			processRunner: processRunner,
			workingDirectoryURL: URL(fileURLWithPath: "/tmp"),
			environment: environment,
			timeout: .seconds(5)
		)
	}
}

// 지정한 process 실행 오류를 반환하는 환경 도구 실행기입니다.
private struct FailingSystemDoctorProcessRunnerSpy: ProcessRunning {
	let error: ProcessRunnerError

	// 지정한 process 실행 오류를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		throw error
	}
}

// Xcode 결과를 반환한 뒤 Swift 실행 오류를 반환하는 실행기입니다.
private actor SwiftFailingSystemDoctorProcessRunnerSpy: ProcessRunning {
	private var didReturnXcode = false

	// 첫 요청에는 Xcode 결과를 반환하고 다음 요청에는 시간 초과를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		guard !didReturnXcode else {
			throw ProcessRunnerError.timedOut
		}

		didReturnXcode = true

		return .init(
			standardOutput: Data("Xcode 26.6\n".utf8),
			terminationStatus: 0
		)
	}
}

// process 요청을 기록하고 미리 정한 결과를 순서대로 반환합니다.
private actor SystemDoctorProcessRunnerSpy: ProcessRunning {
	private var results: [ProcessResult]
	private var requests = [ProcessRequest]()

	// 반환할 process 결과로 시험 대역을 구성합니다.
	init(results: [ProcessResult]) {
		self.results = results
	}

	// process 요청을 저장하고 다음 결과를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult {
		requests.append(request)
		return results.removeFirst()
	}

	// 기록한 process 요청을 반환합니다.
	func sentRequests() -> [ProcessRequest] {
		requests
	}
}
