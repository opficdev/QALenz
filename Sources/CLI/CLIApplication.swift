//
//  CLIApplication.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser
import Foundation
import QALenzCore

// CLI 인수를 처리해 프로세스 결과로 변환합니다.
package enum CLIApplication {
	// CLI 인수를 실행해 프로세스 결과를 만듭니다.
	package static func execute(arguments: [String]) async -> CLIProcessResult {
		let format = CLIOutputFormat.requested(in: arguments)

		do {
			let parsedCommand = try RootCommand.parseAsRoot(arguments)

			if let doctorCommand = parsedCommand as? DoctorCommand {
				return await doctorCommand.execute()
			}

			var command = parsedCommand
			try command.run()

			return .init(standardOutput: nil, standardError: nil, exitStatus: .success)
		} catch {
			return result(for: error, format: format)
		}
	}

	// DoctorReport를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for report: DoctorReport,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: report),
				standardError: nil,
				exitStatus: .init(result: report.result)
			)
		case .json:
			return jsonResult(for: report)
		}
	}

	// 파싱 오류를 출력 형식에 맞는 프로세스 결과로 변환합니다.
	private static func result(
		for error: any Error,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		guard RootCommand.exitCode(for: error) != .success else {
			return .init(
				standardOutput: RootCommand.fullMessage(for: error),
				standardError: nil,
				exitStatus: .success
			)
		}

		let usageError = CLIUsageError(
			message: RootCommand.message(for: error),
			usage: RootCommand.usageString(for: RootCommand.self)
		)

		switch format {
		case .text:
			return .init(
				standardOutput: nil,
				standardError: RootCommand.fullMessage(for: error),
				exitStatus: .usageError
			)
		case .json:
			return jsonResult(for: usageError)
		}
	}

	// CLIUsageError를 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for error: CLIUsageError) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.sortedKeys]
			let data = try encoder.encode(error)

			return .init(
				standardOutput: nil,
				// swiftlint:disable:next optional_data_string_conversion
				standardError: String(decoding: data, as: UTF8.self),
				exitStatus: .usageError
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "CLI usage error encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// DoctorReport를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for report: DoctorReport) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(report)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .init(result: report.result)
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Doctor report encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// DoctorReport의 항목을 사람이 읽을 수 있는 줄 단위 출력으로 변환합니다.
	private static func textOutput(for report: DoctorReport) -> String {
		var lines = report.diagnostics.map { diagnostic in
			let recommendation = diagnostic.recommendation.map { "\n  \($0)" } ?? ""

			return "[\(diagnostic.status.rawValue)] [\(diagnostic.requirement.rawValue)] \(diagnostic.id.rawValue): \(diagnostic.message)\(recommendation)"
		}

		if case let .errored(error) = report.result {
			lines.append("[errored] [\(error.kind.rawValue)] \(error.code.rawValue)")
		}

		return lines.joined(separator: "\n")
	}
}
