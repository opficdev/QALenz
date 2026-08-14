//
//  CLIApplication+Output.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import QALenzCore

// CLI 결과를 text와 JSON 출력으로 변환합니다.
extension CLIApplication {
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

	// RunError를 요청한 출력 형식의 프로세스 오류 결과로 변환합니다.
	package static func result(
		for error: RunError,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		let runResult = RunResult.errored(error)

		switch format {
		case .text:
			return .init(
				standardOutput: nil,
				standardError: textOutput(for: error),
				exitStatus: .init(result: runResult)
			)
		case .json:
			return jsonErrorResult(for: runResult)
		}
	}

	// DiscoveryResult를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for discoveryResult: DiscoveryResult,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: discoveryResult),
				standardError: nil,
				exitStatus: .success
			)
		case .json:
			return jsonResult(for: discoveryResult)
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

	// DiscoveryResult를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for discoveryResult: DiscoveryResult) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(discoveryResult)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .success
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Discovery result encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// RunResult를 JSON 프로세스 오류 결과로 변환합니다.
	private static func jsonErrorResult(for runResult: RunResult) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(runResult)

			return .init(
				standardOutput: nil,
				// swiftlint:disable:next optional_data_string_conversion
				standardError: String(decoding: data, as: UTF8.self),
				exitStatus: .init(result: runResult)
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "CLI error encoding failed.",
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

	// RunError를 사람이 읽을 수 있는 오류 줄로 변환합니다.
	private static func textOutput(for error: RunError) -> String {
		let command = error.context.command.map { " [\($0)]" } ?? ""

		return "[errored] [\(error.kind.rawValue)] \(error.code.rawValue)\(command)"
	}

	// DiscoveryResult의 후보를 사람이 읽을 수 있는 줄 단위 출력으로 변환합니다.
	private static func textOutput(for discoveryResult: DiscoveryResult) -> String {
		[
			textSection(
				named: "projects",
				values: discoveryResult.projects.map(\.path)
			),
			textSection(
				named: "workspaces",
				values: discoveryResult.workspaces.map(\.path)
			),
			textSection(
				named: "schemes",
				values: discoveryResult.schemes.map(\.name)
			),
			textSection(
				named: "simulators",
				values: discoveryResult.simulators.map {
					"\($0.name) | \($0.simulatorId) | \($0.state) | \($0.runtime) | \($0.isAvailable)"
				}
			)
		].joined(separator: "\n")
	}

	// 후보 목록을 이름과 항목 줄로 구성합니다.
	private static func textSection(named name: String, values: [String]) -> String {
		guard !values.isEmpty else {
			return "\(name): []"
		}

		return "\(name):\n\(values.map { "- \($0)" }.joined(separator: "\n"))"
	}
}
