//
//  SystemDoctorEnvironmentProvider.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import QALenzCore

// 현재 macOS와 Xcode 및 Swift 도구 사슬을 진단 항목으로 변환합니다.
package struct SystemDoctorEnvironmentProvider: DoctorEnvironmentProviding, Sendable {
	private static let allowedEnvironmentKeys: Set<String> = [
		"DEVELOPER_DIR",
		"PATH",
		"TMPDIR"
	]

	private let processRunner: any ProcessRunning
	private let workingDirectoryURL: URL
	private let environment: [String: String]
	private let timeout: Duration

	// process 실행 경계와 실행 환경으로 제공자를 구성합니다.
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

	// macOS와 Xcode 및 Swift의 검사 항목을 순서대로 반환합니다.
	package func diagnoseEnvironment() async -> DoctorEnvironmentResult {
		var diagnostics = [diagnoseMacOS()]

		do {
			diagnostics.append(try await diagnoseXcode())
			diagnostics.append(try await diagnoseSwift())

			return .init(diagnostics: diagnostics)
		} catch let error as RunError {
			return .init(diagnostics: diagnostics, error: error)
		} catch {
			return .init(
				diagnostics: diagnostics,
				error: runError(for: error)
			)
		}
	}

	// 현재 macOS version을 진단 항목으로 반환합니다.
	private func diagnoseMacOS() -> DoctorDiagnostic {
		let version = ProcessInfo.processInfo.operatingSystemVersion
		let release = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

		return .init(
			id: .init(rawValue: "macos"),
			requirement: .required,
			status: .available,
			message: "macOS \(release)"
		)
	}

	// 선택된 Xcode version 출력을 진단 항목으로 변환합니다.
	private func diagnoseXcode() async throws -> DoctorDiagnostic {
		do {
			let result = try await run(
				executablePath: "/usr/bin/xcodebuild",
				arguments: ["-version"]
			)

			guard result.terminationStatus == 0 else {
				return .missingXcode
			}

			guard let version = xcodeVersion(from: result.standardOutput) else {
				return .unsupportedXcode
			}

			return .init(
				id: .init(rawValue: "xcode"),
				requirement: .required,
				status: .available,
				message: "Xcode \(version)"
			)
		} catch let error as ProcessRunnerError where error == .executableUnavailable {
			return .missingXcode
		} catch {
			throw runError(for: error)
		}
	}

	// Swift toolchain version 출력을 진단 항목으로 변환합니다.
	private func diagnoseSwift() async throws -> DoctorDiagnostic {
		do {
			let result = try await run(
				executablePath: "/usr/bin/xcrun",
				arguments: ["swift", "--version"]
			)

			guard result.terminationStatus == 0 else {
				return .missingSwift
			}

			guard let version = swiftVersion(from: result.standardOutput) else {
				return .unsupportedSwift
			}

			return .init(
				id: .init(rawValue: "swift"),
				requirement: .required,
				status: .available,
				message: "Swift \(version)"
			)
		} catch let error as ProcessRunnerError where error == .executableUnavailable {
			return .missingSwift
		} catch {
			throw runError(for: error)
		}
	}

	// 허용된 실행 파일과 argument로 process 요청을 실행합니다.
	private func run(
		executablePath: String,
		arguments: [String]
	) async throws -> ProcessResult {
		try await processRunner.run(.init(
			executableURL: URL(fileURLWithPath: executablePath),
			arguments: arguments,
			workingDirectoryURL: workingDirectoryURL,
			environment: allowedEnvironment,
			timeout: timeout
		))
	}

	// process 실행에 전달할 허용된 환경 값만 반환합니다.
	private var allowedEnvironment: [String: String] {
		environment.filter { Self.allowedEnvironmentKeys.contains($0.key) }
	}

	// xcodebuild 출력에서 표시 가능한 Xcode version을 추출합니다.
	private func xcodeVersion(from standardOutput: Data) -> String? {
		guard let output = String(data: standardOutput, encoding: .utf8),
			let match = output.firstMatch(of: /(?m)^Xcode ([0-9]+\.[0-9]+(?:\.[0-9]+)?)[ \t]*$/) else {
			return nil
		}

		return String(match.1)
	}

	// Swift 출력에서 표시 가능한 toolchain version을 추출합니다.
	private func swiftVersion(from standardOutput: Data) -> String? {
		guard let output = String(data: standardOutput, encoding: .utf8),
			let match = output.firstMatch(of: /Apple Swift version ([0-9]+\.[0-9]+\.[0-9]+)/) else {
			return nil
		}

		return String(match.1)
	}
}

// 환경 도구 process 실행 오류를 공통 실행 오류로 정규화합니다.
private extension SystemDoctorEnvironmentProvider {
	func runError(for error: any Error) -> RunError {
		if error is CancellationError {
			return .init(
				kind: .execution,
				code: .init(rawValue: "execution.cancelled")
			)
		}

		if let error = error as? ProcessRunnerError {
			switch error {
			case .timedOut:
				return .init(
					kind: .execution,
					code: .init(rawValue: "execution.timeout")
				)
			case .executableUnavailable:
				return .init(
					kind: .adapter,
					code: .init(rawValue: "adapter.system-doctor.environment.unavailable")
				)
			case .invalidWorkingDirectory, .failedToLaunch:
				return .init(
					kind: .adapter,
					code: .init(rawValue: "adapter.system-doctor.environment.process.failed")
				)
			}
		}

		return .init(
			kind: .adapter,
			code: .init(rawValue: "adapter.system-doctor.environment.process.failed")
		)
	}
}

// 환경 도구 진단의 고정된 오류 항목을 제공합니다.
private extension DoctorDiagnostic {
	static let missingXcode = Self(
		id: .init(rawValue: "xcode"),
		requirement: .required,
		status: .missing,
		message: "선택된 Xcode를 찾을 수 없습니다.",
		recommendation: "Xcode를 설치하거나 xcode-select로 사용할 Xcode를 선택합니다."
	)
	static let unsupportedXcode = Self(
		id: .init(rawValue: "xcode"),
		requirement: .required,
		status: .unsupported,
		message: "Xcode version 출력을 해석할 수 없습니다.",
		recommendation: "지원하는 Xcode version을 사용합니다."
	)
	static let missingSwift = Self(
		id: .init(rawValue: "swift"),
		requirement: .required,
		status: .missing,
		message: "선택된 Xcode의 Swift toolchain을 찾을 수 없습니다.",
		recommendation: "Xcode를 설치하거나 xcode-select로 사용할 Xcode를 선택합니다."
	)
	static let unsupportedSwift = Self(
		id: .init(rawValue: "swift"),
		requirement: .required,
		status: .unsupported,
		message: "Swift version 출력을 해석할 수 없습니다.",
		recommendation: "지원하는 Xcode와 Swift toolchain을 사용합니다."
	)
}
