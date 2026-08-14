//
//  RunCommand.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import ArgumentParser
import Foundation
import QALenzCore

// scenario의 실행 없는 dry-run 계획을 출력하는 명령을 정의합니다.
package struct RunCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "run",
		abstract: "scenario 실행 계획을 확인합니다."
	)
	@Argument(help: "실행 계획을 확인할 scenario 식별자")
	package var scenarioID: String
	@Flag(name: .long, help: "실행하지 않고 계획만 출력합니다.")
	package var dryRun = false
	@OptionGroup
	package var options: CLIOptions

	// 기본 인수와 출력 옵션으로 초기화합니다.
	package init() {}

	// 실제 실행을 아직 제공하지 않으므로 dry-run 명시를 요구합니다.
	package func validate() throws {
		guard dryRun else {
			throw ValidationError("--dry-run을 지정해야 합니다.")
		}
	}

	// 현재 환경에서 dry-run 계획을 출력합니다.
	package func execute() async -> CLIProcessResult {
		await execute(format: options.output)
	}

	// 요청한 출력 형식과 현재 환경에서 dry-run 계획을 출력합니다.
	package func execute(format: CLIOutputFormat) async -> CLIProcessResult {
		await execute(
			format: format,
			loader: ExecutionPlanLoader(),
			currentDirectoryURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		)
	}

	// 주입한 loader로 dry-run 계획을 출력합니다.
	package func execute(
		format: CLIOutputFormat,
		loader: any ExecutionPlanLoading,
		currentDirectoryURL: URL
	) async -> CLIProcessResult {
		let configurationURL = currentDirectoryURL.standardizedFileURL
			.appendingPathComponent(".qalenz", isDirectory: true)
			.appendingPathComponent("config.json", isDirectory: false)

		do {
			return CLIApplication.result(
				for: try loader.load(scenarioID: scenarioID, at: configurationURL),
				format: format
			)
		} catch let errors as ScenarioValidationErrors {
			return CLIApplication.result(
				for: .init(errors: errors.errors),
				format: format
			)
		} catch {
			return CLIApplication.result(for: runError(for: error), format: format)
		}
	}

	// 계획 생성 오류를 원문 없이 공통 오류로 정규화합니다.
	private func runError(for error: any Error) -> RunError {
		guard let error = error as? RunError else {
			return .init(
				kind: .configuration,
				code: .init(rawValue: "configuration.execution-plan.invalid"),
				context: .init(command: "run")
			)
		}

		return error
	}
}
