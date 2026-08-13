//
//  DoctorTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore

// Doctor 진단 조합 계약을 검증합니다.
@Suite
struct DoctorTests {
	// 모든 필수 조건이 충족되면 통과 보고서를 반환하는지 검증합니다.
	@Test
	func 모든_필수_진단이_정상이면_통과_보고서를_반환한다() async {
		let environment = DoctorEnvironmentProviderSpy(diagnostics: [
			.diagnostic(
				id: "macos",
				requirement: .required,
				status: .available,
				message: "macOS 26.0"
			),
			.diagnostic(
				id: "xcode",
				requirement: .required,
				status: .available,
				message: "Xcode 26.6"
			),
			.diagnostic(
				id: "swift",
				requirement: .required,
				status: .available,
				message: "Swift 6.3.3"
			)
		])
		let reporter = XcodeBuildMCPDoctorReporterSpy(diagnostics: [
			.diagnostic(
				id: "xcodebuildmcp.executable",
				requirement: .required,
				status: .available,
				message: "XcodeBuildMCP 2.7.0"
			),
			.diagnostic(
				id: "xcodebuildmcp.output-schema",
				requirement: .required,
				status: .available,
				message: "doctor-report@2"
			)
		])
		let doctor = Doctor(
			environmentProvider: environment,
			xcodeBuildMCPReporter: reporter
		)

		let report = await doctor.diagnose()

		#expect(report.result == .passed)
		#expect(report.diagnostics.map(\.id.rawValue) == [
			"macos",
			"xcode",
			"swift",
			"xcodebuildmcp.executable",
			"xcodebuildmcp.output-schema"
		])
	}

	// 필수 도구 누락이 실패와 해결 안내로 보존되는지 검증합니다.
	@Test
	func 필수_도구_누락은_실패와_해결_안내로_보존된다() async throws {
		let environment = DoctorEnvironmentProviderSpy(diagnostics: [])
		let reporter = XcodeBuildMCPDoctorReporterSpy(diagnostics: [
			.diagnostic(
				id: "xcodebuildmcp.executable",
				requirement: .required,
				status: .missing,
				message: "xcodebuildmcp를 찾을 수 없습니다.",
				recommendation: "XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다."
			)
		])
		let doctor = Doctor(
			environmentProvider: environment,
			xcodeBuildMCPReporter: reporter
		)

		let report = await doctor.diagnose()
		let diagnostic = try #require(report.diagnostics.first)

		#expect(report.result == .failed)
		#expect(diagnostic.status == .missing)
		#expect(diagnostic.recommendation == "XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다.")
	}

	// 지원하지 않는 출력 형식이 도구 누락과 구분되는지 검증합니다.
	@Test
	func 지원하지_않는_출력_형식은_누락과_구분해_실패로_반환한다() async throws {
		let environment = DoctorEnvironmentProviderSpy(diagnostics: [])
		let reporter = XcodeBuildMCPDoctorReporterSpy(diagnostics: [
			.diagnostic(
				id: "xcodebuildmcp.output-schema",
				requirement: .required,
				status: .unsupported,
				message: "doctor-report@3은 지원하지 않습니다.",
				recommendation: "지원하는 XcodeBuildMCP 버전을 사용합니다."
			)
		])
		let doctor = Doctor(
			environmentProvider: environment,
			xcodeBuildMCPReporter: reporter
		)

		let report = await doctor.diagnose()
		let diagnostic = try #require(report.diagnostics.first)

		#expect(report.result == .failed)
		#expect(diagnostic.status == .unsupported)
	}

	// 권장 조건의 누락이 전체 진단을 실패로 바꾸지 않는지 검증합니다.
	@Test
	func 권장_조건_누락은_통과_보고서에_보존된다() async {
		let environment = DoctorEnvironmentProviderSpy(diagnostics: [
			.diagnostic(
				id: "xcode.command-line-tools",
				requirement: .recommended,
				status: .missing,
				message: "Command Line Tools를 찾을 수 없습니다.",
				recommendation: "Xcode Command Line Tools를 설치합니다."
			)
		])
		let reporter = XcodeBuildMCPDoctorReporterSpy(diagnostics: [])
		let doctor = Doctor(
			environmentProvider: environment,
			xcodeBuildMCPReporter: reporter
		)

		let report = await doctor.diagnose()

		#expect(report.result == .passed)
		#expect(report.diagnostics.first?.requirement == .recommended)
		#expect(report.diagnostics.first?.status == .missing)
	}

	// XcodeBuildMCP 실행 오류를 오류 보고서와 분리하는지 검증합니다.
	@Test
	func XcodeBuildMCP_실행_오류를_오류_보고서로_반환한다() async {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.timeout")
		)
		let doctor = Doctor(
			environmentProvider: DoctorEnvironmentProviderSpy(diagnostics: [
				.diagnostic(
					id: "macos",
					requirement: .required,
					status: .available,
					message: "macOS 26.0"
				)
			]),
			xcodeBuildMCPReporter: FailingXcodeBuildMCPDoctorReporterSpy(error: error)
		)

		let report = await doctor.diagnose()

		#expect(report.result == .errored(error))
		#expect(report.diagnostics.map(\.id.rawValue) == ["macos"])
	}

	// 환경 검사 실행 오류에서도 수집한 진단을 오류 보고서로 보존하는지 검증합니다.
	@Test
	func 환경_검사_실행_오류에서도_수집한_진단을_보존한다() async {
		let error = RunError(
			kind: .execution,
			code: .init(rawValue: "execution.timeout")
		)
		let doctor = Doctor(
			environmentProvider: FailingDoctorEnvironmentProviderSpy(
				diagnostics: [
					.diagnostic(
						id: "macos",
						requirement: .required,
						status: .available,
						message: "macOS 26.0"
					),
					.diagnostic(
						id: "xcode",
						requirement: .required,
						status: .available,
						message: "Xcode 26.6"
					)
				],
				error: error
			),
			xcodeBuildMCPReporter: XcodeBuildMCPDoctorReporterSpy(diagnostics: [])
		)

		let report = await doctor.diagnose()

		#expect(report.result == .errored(error))
		#expect(report.diagnostics.map(\.id.rawValue) == ["macos", "xcode"])
	}

	// JSON 출력에 사용할 보고서의 구조화된 왕복 변환을 검증합니다.
	@Test
	func 보고서는_JSON_왕복_변환_후에도_같다() throws {
		let report = DoctorReport(diagnostics: [
			.diagnostic(
				id: "swift",
				requirement: .required,
				status: .available,
				message: "Swift 6.3.3"
			),
			.diagnostic(
				id: "xcodebuildmcp.output-schema",
				requirement: .required,
				status: .unsupported,
				message: "doctor-report@3은 지원하지 않습니다.",
				recommendation: "지원하는 XcodeBuildMCP 버전을 사용합니다."
			)
		])

		let data = try JSONEncoder().encode(report)
		let decoded = try JSONDecoder().decode(DoctorReport.self, from: data)

		#expect(decoded == report)
		#expect(decoded.result == .failed)
	}

	// JSON 결과가 진단 항목과 일치하지 않으면 복원을 거부하는지 검증합니다.
	@Test
	func 진단_항목과_일치하지_않는_result는_JSON_복원을_거부한다() {
		let json = """
		{
		  "diagnostics": [
		    {
		      "id": "swift",
		      "requirement": "required",
		      "status": "missing",
		      "message": "Swift를 찾을 수 없습니다."
		    }
		  ],
		  "result": {
		    "status": "passed"
		  }
		}
		"""

		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(DoctorReport.self, from: Data(json.utf8))
		}
	}
}

// 고정된 환경 진단을 제공하는 시험 대역입니다.
private struct DoctorEnvironmentProviderSpy: DoctorEnvironmentProviding {
	let sentDiagnostics: [DoctorDiagnostic]

	// 반환할 고정 진단으로 시험 대역을 구성합니다.
	init(diagnostics: [DoctorDiagnostic]) {
		sentDiagnostics = diagnostics
	}

	// 고정된 환경 진단을 반환합니다.
	func diagnoseEnvironment() async -> DoctorEnvironmentResult {
		.init(diagnostics: sentDiagnostics)
	}
}

// 지정한 실행 오류를 반환하는 환경 진단 대역입니다.
private struct FailingDoctorEnvironmentProviderSpy: DoctorEnvironmentProviding {
	let diagnostics: [DoctorDiagnostic]
	let error: RunError

	// 지정한 진단과 실행 오류를 반환합니다.
	func diagnoseEnvironment() async -> DoctorEnvironmentResult {
		.init(diagnostics: diagnostics, error: error)
	}
}

// 고정된 XcodeBuildMCP 진단을 제공하는 시험 대역입니다.
private struct XcodeBuildMCPDoctorReporterSpy: XcodeBuildMCPDoctorReporting {
	let sentDiagnostics: [DoctorDiagnostic]

	// 반환할 고정 진단으로 시험 대역을 구성합니다.
	init(diagnostics: [DoctorDiagnostic]) {
		sentDiagnostics = diagnostics
	}

	// 고정된 XcodeBuildMCP 진단을 반환합니다.
	func diagnoseXcodeBuildMCP() async throws -> [DoctorDiagnostic] {
		sentDiagnostics
	}
}

// 지정한 실행 오류를 반환하는 XcodeBuildMCP 진단 대역입니다.
private struct FailingXcodeBuildMCPDoctorReporterSpy: XcodeBuildMCPDoctorReporting {
	let error: RunError

	// 지정한 실행 오류를 반환합니다.
	func diagnoseXcodeBuildMCP() async throws -> [DoctorDiagnostic] {
		throw error
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
