//
//  XcodeBuildMCPDoctorReporter.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import QALenzCore

// XcodeBuildMCP CLI 진단 결과를 QALenz Doctor 항목으로 변환합니다.
package struct XcodeBuildMCPDoctorReporter: XcodeBuildMCPDoctorReporting, Sendable {
	private static let doctorSchema = "xcodebuildmcp.output.doctor-report"
	private static let doctorSchemaVersion = "2"
	private static let allowedEnvironmentKeys: Set<String> = [
		"DEVELOPER_DIR",
		"PATH",
		"TMPDIR"
	]
	private static let fixedDiagnosticValues = [
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

	private let processRunner: any ProcessRunning
	private let workingDirectoryURL: URL
	private let environment: [String: String]
	private let timeout: Duration

	// process 실행 경계와 실행 환경으로 reporter를 구성합니다.
	package init(
		processRunner: any ProcessRunning = FoundationProcessRunner(),
		workingDirectoryURL: URL,
		environment: [String: String],
		timeout: Duration
	) {
		self.processRunner = processRunner
		self.workingDirectoryURL = workingDirectoryURL
		self.environment = environment
		self.timeout = timeout
	}

	// XcodeBuildMCP 실행 파일과 doctor 결과를 순서대로 진단합니다.
	package func diagnoseXcodeBuildMCP() async -> [DoctorDiagnostic] {
		let executableDiagnostic = await diagnoseExecutable()

		guard executableDiagnostic.status == .available else {
			return [executableDiagnostic]
		}

		let doctorDiagnostics = await diagnoseDoctorReport()

		return [executableDiagnostic] + doctorDiagnostics
	}

	// PATH에서 실행 파일을 찾고 version 출력을 확인합니다.
	private func diagnoseExecutable() async -> DoctorDiagnostic {
		do {
			let result = try await run(arguments: ["xcodebuildmcp", "--version"])

			guard result.terminationStatus == 0 else {
				return diagnostic(for: .fixed(.executableMissing))
			}

			guard let version = version(from: result.standardOutput) else {
				return diagnostic(for: .fixed(.executableUnsupported))
			}

			return diagnostic(for: .executableAvailable(version))
		} catch {
			return diagnostic(for: .fixed(.executableMissing))
		}
	}

	// doctor의 구조화된 출력과 세부 check를 진단 항목으로 변환합니다.
	private func diagnoseDoctorReport() async -> [DoctorDiagnostic] {
		do {
			let result = try await run(arguments: ["xcodebuildmcp", "doctor", "--output", "json"])

			guard result.terminationStatus == 0 else {
				return [diagnostic(for: .fixed(.doctorUnavailable))]
			}

			let report = try JSONDecoder().decode(
				XcodeBuildMCPDoctorReport.self,
				from: result.standardOutput
			)

			guard !report.didError else {
				return [diagnostic(for: .fixed(.doctorUnavailable))]
			}

			guard report.schema == Self.doctorSchema,
				report.schemaVersion == Self.doctorSchemaVersion else {
				return [diagnostic(for: .fixed(.doctorSchemaUnsupported))]
			}

			guard let data = report.data else {
				return [diagnostic(for: .fixed(.doctorOutputInvalid))]
			}

			return [diagnostic(for: .fixed(.doctorSchemaAvailable))] + data.checks.enumerated().map { index, check in
				diagnostic(for: .doctorCheck(check, index: index))
			}
		} catch {
			return [diagnostic(for: .fixed(.doctorOutputInvalid))]
		}
	}

	// 실행 파일 탐색에 사용할 process 요청을 실행합니다.
	private func run(arguments: [String]) async throws -> ProcessResult {
		try await processRunner.run(.init(
			executableURL: URL(fileURLWithPath: "/usr/bin/env"),
			arguments: arguments,
			workingDirectoryURL: workingDirectoryURL,
			environment: allowedEnvironment,
			timeout: timeout
		))
	}

	// 비구조화된 version 출력에서 표시 가능한 semantic version만 추출합니다.
	private func version(from standardOutput: Data) -> String? {
		guard let version = String(data: standardOutput, encoding: .utf8)?
			.trimmingCharacters(in: .whitespacesAndNewlines),
			version.wholeMatch(of: /v?[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?/) != nil else {
			return nil
		}

		return version
	}

	// 알려진 doctor check 이름 또는 순번 기반 식별자를 반환합니다.
	private func doctorCheckName(
		for check: XcodeBuildMCPDoctorReport.Check,
		index: Int
	) -> String {
		switch check.name {
		case "xcode":
			"xcode"
		case "manifest-tools":
			"manifest-tools"
		case "axe":
			"axe"
		default:
			"check-\(index + 1)"
		}
	}

	// process 실행에 전달할 허용된 환경 값만 반환합니다.
	private var allowedEnvironment: [String: String] {
		environment.filter { Self.allowedEnvironmentKeys.contains($0.key) }
	}

	// 진단 사건을 QALenz Doctor 계약으로 변환합니다.
	private func diagnostic(
		for event: XcodeBuildMCPDoctorDiagnosticEvent
	) -> DoctorDiagnostic {
		let value = switch event {
		case .executableAvailable(let version):
			XcodeBuildMCPDoctorDiagnosticValue(
				id: "xcodebuildmcp.executable",
				requirement: .required,
				status: .available,
				message: "XcodeBuildMCP \(version)",
				recommendation: nil
			)
		case .fixed(let event):
			Self.fixedDiagnosticValues[event.rawValue]
		case .doctorCheck(let check, let index):
			doctorCheckValue(for: check, index: index)
		}

		return .init(
			id: .init(rawValue: value.id),
			requirement: value.requirement,
			status: value.status,
			message: value.message,
			recommendation: value.recommendation
		)
	}

	// doctor check 결과를 공통 진단 값으로 정규화합니다.
	private func doctorCheckValue(
		for check: XcodeBuildMCPDoctorReport.Check,
		index: Int
	) -> XcodeBuildMCPDoctorDiagnosticValue {
		let name = doctorCheckName(for: check, index: index)
		let status = switch check.status {
		case .available:
			DoctorDiagnostic.Status.available
		case .warning, .error:
			DoctorDiagnostic.Status.missing
		}
		let requirement = switch name {
		case "xcode", "manifest-tools":
			DoctorDiagnostic.Requirement.required
		default:
			check.status == .error
				? DoctorDiagnostic.Requirement.required
				: DoctorDiagnostic.Requirement.recommended
		}
		let recommendation = status == .available
			? nil
			: "XcodeBuildMCP doctor의 안내에 따라 \(name) 항목을 확인합니다."
		let message = status == .available
			? "XcodeBuildMCP \(name) 항목을 확인했습니다."
			: "XcodeBuildMCP \(name) 항목을 확인할 수 없습니다."

		return .init(
			id: "xcodebuildmcp.doctor.\(name)",
			requirement: requirement,
			status: status,
			message: message,
			recommendation: recommendation
		)
	}
}

// reporter 내부에서 정규화할 진단 사건을 표현합니다.
private enum XcodeBuildMCPDoctorDiagnosticEvent {
	case executableAvailable(String)
	case fixed(XcodeBuildMCPDoctorFixedDiagnosticEvent)
	case doctorCheck(XcodeBuildMCPDoctorReport.Check, index: Int)
}

// 고정 진단 값의 순번을 나타냅니다.
private enum XcodeBuildMCPDoctorFixedDiagnosticEvent: Int {
	case executableMissing
	case executableUnsupported
	case doctorUnavailable
	case doctorSchemaAvailable
	case doctorSchemaUnsupported
	case doctorOutputInvalid
}

// DoctorDiagnostic 생성에 사용할 정규화된 값을 나타냅니다.
private struct XcodeBuildMCPDoctorDiagnosticValue {
	let id: String
	let requirement: DoctorDiagnostic.Requirement
	let status: DoctorDiagnostic.Status
	let message: String
	let recommendation: String?
}

// XcodeBuildMCP doctor JSON 출력 중 QALenz가 사용하는 필드를 해석합니다.
private struct XcodeBuildMCPDoctorReport: Decodable {
	let schema: String
	let schemaVersion: String
	let didError: Bool
	let data: Data?
}

// doctor 출력의 data 항목을 해석합니다.
private extension XcodeBuildMCPDoctorReport {
	struct Data: Decodable {
		let serverVersion: String
		let checks: [Check]
	}

	// XcodeBuildMCP가 제공한 개별 환경 확인 결과를 해석합니다.
	struct Check: Decodable {
		let name: String
		let status: Status
		let message: String
	}

	// XcodeBuildMCP doctor check 상태를 나타냅니다.
	enum Status: String, Decodable {
		case available = "ok"
		case warning
		case error
	}
}
