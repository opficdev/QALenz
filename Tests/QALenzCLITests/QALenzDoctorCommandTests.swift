//
//  QALenzDoctorCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

// qalenz doctor 명령의 출력과 종료 상태 연결을 검증합니다.
@Suite
struct QALenzDoctorCommandTests {
	// text 출력에서 진단 상태와 안내를 보존하는지 검증합니다.
	@Test
	func text_출력이_진단_상태와_안내를_보존한다() async throws {
		let result = await execute(
			format: .text,
			environmentDiagnostics: [.diagnostic(
				id: "swift",
				requirement: .required,
				status: .available,
				message: "Swift 6.3.3"
			)],
			xcodeBuildMCPDiagnostics: [.diagnostic(
				id: "xcodebuildmcp.executable",
				requirement: .required,
				status: .missing,
				message: "xcodebuildmcp를 찾을 수 없습니다.",
				recommendation: "XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다."
			)]
		)
		let output = try #require(result.standardOutput)

		#expect(result.exitStatus == .verificationFailure)
		#expect(output.contains("[available] [required] swift: Swift 6.3.3"))
		#expect(output.contains("[missing] [required] xcodebuildmcp.executable: xcodebuildmcp를 찾을 수 없습니다."))
		#expect(output.contains("XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다."))
		#expect(result.standardError == nil)
	}

	// JSON 출력이 text 출력과 같은 보고서와 종료 상태를 제공하는지 검증합니다.
	@Test
	func JSON_출력이_text_출력과_같은_보고서와_종료_상태를_제공한다() async throws {
		let environmentDiagnostics: [DoctorDiagnostic] = [.diagnostic(
			id: "macos",
			requirement: .required,
			status: .available,
			message: "macOS 26.5.2"
		)]
		let xcodeBuildMCPDiagnostics: [DoctorDiagnostic] = [.diagnostic(
			id: "xcodebuildmcp.doctor.axe",
			requirement: .recommended,
			status: .missing,
			message: "XcodeBuildMCP axe 항목을 확인할 수 없습니다.",
			recommendation: "XcodeBuildMCP doctor의 안내에 따라 axe 항목을 확인합니다."
		)]
		let text = await execute(
			format: .text,
			environmentDiagnostics: environmentDiagnostics,
			xcodeBuildMCPDiagnostics: xcodeBuildMCPDiagnostics
		)
		let json = await execute(
			format: .json,
			environmentDiagnostics: environmentDiagnostics,
			xcodeBuildMCPDiagnostics: xcodeBuildMCPDiagnostics
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))
		let report = try JSONDecoder().decode(DoctorReport.self, from: data)

		#expect(text.exitStatus == .success)
		#expect(json.exitStatus == text.exitStatus)
		#expect(report.result == .passed)
		#expect(report.diagnostics == environmentDiagnostics + xcodeBuildMCPDiagnostics)
		#expect(json.standardError == nil)
	}

	// 하위 명령과 출력 옵션을 해석하는지 검증합니다.
	@Test
	func doctor_하위_명령과_JSON_출력_옵션을_해석한다() throws {
		let command = try QALenzRootCommand.parseAsRoot(["doctor", "--output", "json"])
		let doctor = try #require(command as? QALenzDoctorCommand)

		#expect(doctor.options.output == .json)
	}

	// 가짜 제공자로 doctor 명령을 실행합니다.
	private func execute(
		format: CLIOutputFormat,
		environmentDiagnostics: [DoctorDiagnostic],
		xcodeBuildMCPDiagnostics: [DoctorDiagnostic]
	) async -> CLIProcessResult {
		await QALenzDoctorCommand().execute(
			format: format,
			environmentProvider: DoctorEnvironmentProviderSpy(
				diagnostics: environmentDiagnostics
			),
			xcodeBuildMCPReporter: XcodeBuildMCPDoctorReporterSpy(
				diagnostics: xcodeBuildMCPDiagnostics
			)
		)
	}
}

// 고정된 환경 진단을 제공하는 시험 대역입니다.
private struct DoctorEnvironmentProviderSpy: DoctorEnvironmentProviding {
	let diagnostics: [DoctorDiagnostic]

	// 고정된 환경 진단을 반환합니다.
	func diagnoseEnvironment() async -> [DoctorDiagnostic] {
		diagnostics
	}
}

// 고정된 XcodeBuildMCP 진단을 제공하는 시험 대역입니다.
private struct XcodeBuildMCPDoctorReporterSpy: XcodeBuildMCPDoctorReporting {
	let diagnostics: [DoctorDiagnostic]

	// 고정된 XcodeBuildMCP 진단을 반환합니다.
	func diagnoseXcodeBuildMCP() async -> [DoctorDiagnostic] {
		diagnostics
	}
}

// DoctorDiagnostic 시험 값을 간결하게 구성합니다.
private extension DoctorDiagnostic {
	static func diagnostic(
		id: String,
		requirement: Requirement,
		status: Status,
		message: String,
		recommendation: String? = nil
	) -> Self {
		.init(
			id: .init(rawValue: id),
			requirement: requirement,
			status: status,
			message: message,
			recommendation: recommendation
		)
	}
}
