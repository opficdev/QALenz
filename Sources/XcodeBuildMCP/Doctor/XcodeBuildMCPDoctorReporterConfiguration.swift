//
//  XcodeBuildMCPDoctorReporterConfiguration.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import QALenzCore

// XcodeBuildMCP doctor reporter의 고정 진단 값을 제공합니다.
enum XcodeBuildMCPDoctorReporterConfiguration {
	static let fixedDiagnosticValues = [
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.executable",
			requirement: .required,
			status: .missing,
			message: "xcodebuildmcp를 찾을 수 없습니다.",
			recommendation: "XcodeBuildMCP를 설치한 뒤 PATH를 확인합니다."
		),
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.executable",
			requirement: .required,
			status: .unsupported,
			message: "xcodebuildmcp version 출력을 해석할 수 없습니다.",
			recommendation: "지원하는 XcodeBuildMCP version을 사용합니다."
		),
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.output-schema",
			requirement: .required,
			status: .missing,
			message: "XcodeBuildMCP doctor의 구조화된 출력을 확인할 수 없습니다.",
			recommendation: "설치된 XcodeBuildMCP가 QALenz가 요구하는 doctor CLI 출력을 지원하는지 확인합니다."
		),
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.output-schema",
			requirement: .required,
			status: .available,
			message: "xcodebuildmcp.output.doctor-report@2",
			recommendation: nil
		),
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.output-schema",
			requirement: .required,
			status: .unsupported,
			message: "XcodeBuildMCP doctor 출력 형식은 지원하지 않습니다.",
			recommendation: "지원하는 XcodeBuildMCP 버전을 사용합니다."
		),
		XcodeBuildMCPDoctorDiagnosticValue(
			id: "xcodebuildmcp.output-schema",
			requirement: .required,
			status: .unsupported,
			message: "XcodeBuildMCP doctor의 JSON 응답을 해석할 수 없습니다.",
			recommendation: "지원하는 XcodeBuildMCP 버전을 사용합니다."
		)
	]
}

// DoctorDiagnostic 생성에 사용할 정규화된 값을 나타냅니다.
struct XcodeBuildMCPDoctorDiagnosticValue {
	let id: String
	let requirement: DoctorDiagnostic.Requirement
	let status: DoctorDiagnostic.Status
	let message: String
	let recommendation: String?
}
