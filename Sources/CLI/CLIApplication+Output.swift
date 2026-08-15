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

	// ExecutionPlan을 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for plan: ExecutionPlan,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: plan),
				standardError: nil,
				exitStatus: .success
			)
		case .json:
			return jsonResult(for: plan)
		}
	}

	// ExecutionPlanValidationFailure를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for failure: ExecutionPlanValidationFailure,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: failure),
				standardError: nil,
				exitStatus: .verificationFailure
			)
		case .json:
			return jsonResult(for: failure)
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

	// ScenarioCatalog를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for catalog: ScenarioCatalog,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: catalog),
				standardError: nil,
				exitStatus: .init(result: catalog.result)
			)
		case .json:
			return jsonResult(for: catalog)
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

	// ScenarioCatalog를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for catalog: ScenarioCatalog) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(catalog)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .init(result: catalog.result)
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Scenario catalog encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// ExecutionPlan을 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for plan: ExecutionPlan) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(plan)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .success
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Execution plan encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// ExecutionPlanValidationFailure를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for failure: ExecutionPlanValidationFailure) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(failure)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .verificationFailure
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Execution plan validation failure encoding failed.",
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

	// ScenarioCatalog의 항목과 validation 오류를 사람이 읽을 수 있는 줄로 변환합니다.
	private static func textOutput(for catalog: ScenarioCatalog) -> String {
		guard !catalog.entries.isEmpty else {
			return "scenarios: []"
		}

		return catalog.entries.map { entry in
			let summary = "[\(entry.status.rawValue)] \(entry.id ?? "-") | \(entry.name ?? "-") | \(entry.profile ?? "-")"
			let errors = entry.errors.map {
				"  \($0.code.rawValue) | \($0.filePath) | \($0.keyPath)"
			}

			return ([summary] + errors).joined(separator: "\n")
		}.joined(separator: "\n")
	}

	// ExecutionPlan을 사람이 읽는 줄 단위 출력으로 변환합니다.
	private static func textOutput(for plan: ExecutionPlan) -> String {
		let requirements = plan.testDataRequirements.map {
			"\($0.operation.rawValue) | \($0.resource)"
		}
		let targets = plan.targets.map { target in
			let steps = target.steps.map {
				"  \($0.id) | \($0.action.rawValue) | \($0.sideEffects.map(\.rawValue).joined(separator: ",")) | \(selectorSummary($0.selector)) | \(parameterSummary($0.parameters))"
			}.joined(separator: "\n")
			let assertions = target.assertions.map(referenceSummary).joined(separator: ",")
			let evidence = target.evidence.map(referenceSummary).joined(separator: ",")

			return """
			\(target.target.identifier) | \(target.outputDirectoryPath)
			\(steps)
			  assertions | \(assertions)
			  evidence | \(evidence)
			"""
		}

		return [
			"scenario: \(plan.scenarioID)",
			"profile: \(plan.profile)",
			"projectRoot: \(plan.projectRootPath)",
			"xcodeBuildMCPProfile: \(plan.xcodeBuildMCPProfile)",
			"outputDirectory: \(plan.outputDirectoryPath)",
			textSection(named: "testDataRequirements", values: requirements),
			textSection(named: "targets", values: targets)
		].joined(separator: "\n")
	}

	// ExecutionPlanValidationFailure의 오류를 사람이 읽는 줄 단위 출력으로 변환합니다.
	private static func textOutput(for failure: ExecutionPlanValidationFailure) -> String {
		failure.errors.map {
			"\($0.code.rawValue) | \($0.filePath) | \($0.keyPath)"
		}.joined(separator: "\n")
	}

	// selector의 제공 값을 사람이 읽는 실행 계획 문자열로 변환합니다.
	private static func selectorSummary(_ selector: ScenarioSelector?) -> String {
		guard let selector else { return "selector: -" }

		return "selector: \(selector.identifier ?? "-") | \(selector.label ?? "-") | \(selector.role ?? "-") | \(selector.value ?? "-")"
	}

	// parameter의 손실 없는 계획 표현을 반환합니다.
	private static func parameterSummary(_ parameter: ExecutionPlanParameter?) -> String {
		parameter.map { "parameters: \(String(describing: $0))" } ?? "parameters: -"
	}

	// assertion 또는 evidence 참조의 parameter 표현을 반환합니다.
	private static func referenceSummary(_ reference: ExecutionPlanStepReference) -> String {
		"\(reference.afterStepID) | \(parameterSummary(reference.parameters))"
	}

	// 후보 목록을 이름과 항목 줄로 구성합니다.
	private static func textSection(named name: String, values: [String]) -> String {
		guard !values.isEmpty else {
			return "\(name): []"
		}

		return "\(name):\n\(values.map { "- \($0)" }.joined(separator: "\n"))"
	}
}
