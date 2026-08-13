//
//  Doctor.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// 실행 환경 검사 결과를 제공하는 계약입니다.
package protocol DoctorEnvironmentProviding: Sendable {
	// 실행 환경의 검사 항목을 반환합니다.
	func diagnoseEnvironment() async throws -> [DoctorDiagnostic]
}

// XcodeBuildMCP 호환성 검사 결과를 제공하는 계약입니다.
package protocol XcodeBuildMCPDoctorReporting: Sendable {
	// XcodeBuildMCP의 검사 항목을 반환합니다.
	func diagnoseXcodeBuildMCP() async throws -> [DoctorDiagnostic]
}

// 환경과 XcodeBuildMCP 검사 결과를 단일 보고서로 조합합니다.
package struct Doctor: Sendable {
	private let environmentProvider: any DoctorEnvironmentProviding
	private let xcodeBuildMCPReporter: any XcodeBuildMCPDoctorReporting

	// 두 검사 결과 제공자로 초기화합니다.
	package init(
		environmentProvider: any DoctorEnvironmentProviding,
		xcodeBuildMCPReporter: any XcodeBuildMCPDoctorReporting
	) {
		self.environmentProvider = environmentProvider
		self.xcodeBuildMCPReporter = xcodeBuildMCPReporter
	}

	// 제공자의 검사 항목을 순서대로 조합한 보고서를 반환합니다.
	package func diagnose() async -> DoctorReport {
		let environmentDiagnostics: [DoctorDiagnostic]

		do {
			environmentDiagnostics = try await environmentProvider.diagnoseEnvironment()
		} catch let error as RunError {
			return .init(diagnostics: [], error: error)
		} catch {
			return .init(
				diagnostics: [],
				error: .init(
					kind: .adapter,
					code: .init(rawValue: "adapter.system-doctor.environment.failed")
				)
			)
		}

		do {
			let xcodeBuildMCPDiagnostics = try await xcodeBuildMCPReporter.diagnoseXcodeBuildMCP()

			return .init(
				diagnostics: environmentDiagnostics + xcodeBuildMCPDiagnostics
			)
		} catch let error as RunError {
			return .init(diagnostics: environmentDiagnostics, error: error)
		} catch {
			return .init(
				diagnostics: environmentDiagnostics,
				error: .init(
					kind: .adapter,
					code: .init(rawValue: "adapter.xcodebuildmcp.doctor.failed")
				)
			)
		}
	}
}
