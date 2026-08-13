//
//  XcodeBuildMCPDoctorReporterTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore
@testable import QALenzXcodeBuildMCP

// XcodeBuildMCP doctor 결과의 QALenz 진단 변환을 검증합니다.
@Suite
struct XcodeBuildMCPDoctorReporterTests {
	// 가짜 실행 파일의 version과 doctor check를 진단 항목으로 변환하는지 검증합니다.
	@Test
	func 가짜_실행_파일의_version과_doctor_check를_진단_항목으로_변환한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		try installFakeXcodeBuildMCP(in: directory)
		let reporter = makeReporter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path]
		)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.id.rawValue) == [
			"xcodebuildmcp.executable",
			"xcodebuildmcp.output-schema",
			"xcodebuildmcp.doctor.xcode",
			"xcodebuildmcp.doctor.manifest-tools",
			"xcodebuildmcp.doctor.axe"
		])
		#expect(diagnostics[0].status == .available)
		#expect(diagnostics[0].message == "XcodeBuildMCP 2.7.0-fixture")
		#expect(diagnostics[1].status == .available)
		#expect(diagnostics[2].requirement == .required)
		#expect(diagnostics[2].status == .available)
		#expect(diagnostics[3].requirement == .required)
		#expect(diagnostics[3].status == .available)
		#expect(diagnostics[4].requirement == .recommended)
		#expect(diagnostics[4].status == .missing)
		#expect(diagnostics[4].recommendation?.contains("axe") == true)
	}

	// PATH에 실행 파일이 없으면 설치 안내를 포함한 누락 진단을 반환하는지 검증합니다.
	@Test
	func PATH에_실행_파일이_없으면_누락_진단을_반환한다() async throws {
		let directory = try makeTemporaryDirectory()
		defer { try? FileManager.default.removeItem(at: directory) }
		let reporter = makeReporter(
			workingDirectoryURL: directory,
			environment: ["PATH": directory.path]
		)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.count == 1)
		#expect(diagnostics[0].id.rawValue == "xcodebuildmcp.executable")
		#expect(diagnostics[0].requirement == .required)
		#expect(diagnostics[0].status == .missing)
		#expect(diagnostics[0].recommendation == "XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다.")
	}

	// version command의 일반 종료 실패를 adapter 실행 오류로 반환하는지 검증합니다.
	@Test(arguments: [Int32(1), 126])
	func version_command의_일반_종료_실패를_adapter_실행_오류로_반환한다(
		status: Int32
	) async {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(
				standardOutput: Data("secret-token-value".utf8),
				terminationStatus: status
			)
		])
		let reporter = makeReporter(processRunner: runner)

		do {
			_ = try await reporter.diagnoseXcodeBuildMCP()
			Issue.record("RunError를 반환해야 합니다.")
		} catch let error as RunError {
			#expect(error.kind == .adapter)
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.command.failed")
			#expect(!String(describing: error).contains("secret-token-value"))
		} catch {
			Issue.record("RunError 대신 다른 오류를 반환했습니다.")
		}
	}

	// version 출력이 허용된 형식이 아니면 원문을 노출하지 않는지 검증합니다.
	@Test
	func version_출력이_허용된_형식이_아니면_원문을_노출하지_않는다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(
					standardOutput: Data("2.7.0-fixture\nsecret-token-value".utf8),
				terminationStatus: 0
			),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":false,"error":null,"data":{"serverVersion":"2.7.0-fixture","checks":[]}}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.unsupported])
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// 지원하지 않는 주 version을 실행 파일 호환성 실패로 변환하는지 검증합니다.
	@Test(arguments: ["1.9.0", "3.0.0"])
	func 지원하지_않는_주_version을_호환성_실패로_변환한다(version: String) async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("\(version)\n".utf8), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.unsupported])
		#expect(diagnostics[0].id.rawValue == "xcodebuildmcp.executable")
	}

	// doctor command의 비정상 종료가 원본 출력 없이 누락 진단으로 변환되는지 검증합니다.
	@Test
	func doctor_command의_비정상_종료가_누락_진단으로_변환된다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
				.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data("secret-token-value".utf8), terminationStatus: 1)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .missing])
		let diagnostic = try #require(diagnostics.last)
		#expect(diagnostic.message == "XcodeBuildMCP doctor의 구조화된 출력을 확인할 수 없습니다.")
		#expect(diagnostic.recommendation == "설치된 XcodeBuildMCP가 QALenz가 요구하는 doctor CLI 출력을 지원하는지 확인합니다.")
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// didError 응답의 error 값이 진단 원문에 포함되지 않는지 검증합니다.
	@Test
	func didError_응답의_error_값을_진단에_포함하지_않는다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
				.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":true,"error":"secret-token-value","data":null}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .missing])
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// 성공으로 표시된 응답의 error 값을 형식 오류로 변환하는지 검증합니다.
	@Test
	func 성공으로_표시된_응답의_error_값을_형식_오류로_변환한다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":false,"error":"secret-token-value","data":{"serverVersion":"2.7.0-fixture","checks":[]}}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .unsupported])
		#expect(diagnostics[1].message == "XcodeBuildMCP doctor의 JSON 응답을 해석할 수 없습니다.")
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// doctor JSON이 형식에 맞지 않으면 지원하지 않는 출력 진단을 반환하는지 검증합니다.
	@Test
	func doctor_JSON이_형식에_맞지_않으면_지원하지_않는_출력_진단을_반환한다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data("not-json".utf8), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .unsupported])
		#expect(diagnostics[1].message == "XcodeBuildMCP doctor의 JSON 응답을 해석할 수 없습니다.")
	}

	// 지원하지 않는 doctor schema 원문을 진단에 포함하지 않는지 검증합니다.
	@Test
	func 지원하지_않는_doctor_schema_원문을_진단에_포함하지_않는다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"secret-token-value","schemaVersion":"secret-token-value","didError":false,"error":null,"data":null}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .unsupported])
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// doctor check 원문이 진단에 포함되지 않는지 검증합니다.
	@Test
	func doctor_check_원문을_진단에_포함하지_않는다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":false,"error":null,"data":{"serverVersion":"2.7.0-fixture","checks":[{"name":"secret-token-value","status":"warning","message":"secret-token-value"}]}}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.status) == [.available, .available, .missing, .missing, .missing])
		#expect(!String(describing: diagnostics).contains("secret-token-value"))
	}

	// 필수 doctor check가 응답에 없으면 누락 진단을 반환하는지 검증합니다.
	@Test
	func 필수_doctor_check가_없으면_누락_진단을_반환한다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":false,"error":null,"data":{"serverVersion":"2.7.0-fixture","checks":[]}}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(processRunner: runner)

		let diagnostics = try await reporter.diagnoseXcodeBuildMCP()

		#expect(diagnostics.map(\.id.rawValue) == [
			"xcodebuildmcp.executable",
			"xcodebuildmcp.output-schema",
			"xcodebuildmcp.doctor.xcode",
			"xcodebuildmcp.doctor.manifest-tools"
		])
		#expect(diagnostics.suffix(2).allSatisfy {
			$0.requirement == .required && $0.status == .missing
		})
	}

	// version과 doctor 요청이 필요한 환경으로 실행되는지 검증합니다.
	@Test
	func version과_doctor_요청이_필요한_환경으로_실행된다() async throws {
		let runner = DoctorProcessRunnerSpy(results: [
			.init(standardOutput: Data("2.7.0-fixture\n".utf8), terminationStatus: 0),
			.init(standardOutput: Data(
				"""
				{"schema":"xcodebuildmcp.output.doctor-report","schemaVersion":"2","didError":false,"error":null,"data":{"serverVersion":"2.7.0-fixture","checks":[]}}
				""".utf8
			), terminationStatus: 0)
		])
		let reporter = makeReporter(
			processRunner: runner,
			environment: [
				"PATH": "/usr/bin:/bin",
				"DEVELOPER_DIR": "/Applications/Xcode.app",
				"SECRET_TOKEN": "secret-token-value"
			]
		)

		_ = try await reporter.diagnoseXcodeBuildMCP()
		let requests = await runner.receivedRequests

		#expect(requests.map(\.arguments) == [
			["xcodebuildmcp", "--version"],
			["xcodebuildmcp", "doctor", "doctor", "--output", "json"]
		])
		#expect(requests.allSatisfy {
			$0.executableURL == URL(fileURLWithPath: "/usr/bin/env")
		})
		#expect(requests[0].environment == [
			"PATH": "/usr/bin:/bin",
			"DEVELOPER_DIR": "/Applications/Xcode.app"
		])
		#expect(requests[1].environment == [
			"PATH": "/usr/bin:/bin",
			"DEVELOPER_DIR": "/Applications/Xcode.app",
			"XCODEBUILDMCP_DEBUG": "true"
		])
	}

	// doctor process timeout을 실행 오류로 반환하는지 검증합니다.
	@Test
	func doctor_process_timeout을_실행_오류로_반환한다() async {
		let reporter = makeReporter(processRunner: TimeoutProcessRunnerSpy())

		do {
			_ = try await reporter.diagnoseXcodeBuildMCP()
			Issue.record("RunError를 반환해야 합니다.")
		} catch let error as RunError {
			#expect(error.kind == .execution)
			#expect(error.code.rawValue == "execution.timeout")
		} catch {
			Issue.record("RunError 대신 다른 오류를 반환했습니다.")
		}
	}

	// env 실행 파일 오류를 실행 파일 누락 진단으로 변환하지 않는지 검증합니다.
	@Test
	func env_실행_파일_오류를_실행_오류로_반환한다() async {
		let reporter = makeReporter(
			processRunner: FailingProcessRunnerSpy(
				error: .executableUnavailable
			)
		)

		do {
			_ = try await reporter.diagnoseXcodeBuildMCP()
			Issue.record("RunError를 반환해야 합니다.")
		} catch let error as RunError {
			#expect(error.kind == .adapter)
			#expect(error.code.rawValue == "adapter.xcodebuildmcp.unavailable")
		} catch {
			Issue.record("RunError 대신 다른 오류를 반환했습니다.")
		}
	}

}
