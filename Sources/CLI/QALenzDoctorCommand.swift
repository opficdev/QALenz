//
//  QALenzDoctorCommand.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import ArgumentParser
import Foundation
import QALenzCore
import QALenzXcodeBuildMCP

// 실행 환경 진단을 제공하는 qalenz 하위 명령을 정의합니다.
package struct QALenzDoctorCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "doctor",
		abstract: "실행 환경과 XcodeBuildMCP 호환성을 진단합니다."
	)
	@OptionGroup
	package var options: CLIOptions

	// 기본 출력 옵션으로 명령을 초기화합니다.
	package init() {}

	// 현재 환경으로 Doctor를 조립해 결과를 반환합니다.
	package func execute() async -> CLIProcessResult {
		await execute(format: options.output)
	}

	// 요청한 출력 형식과 현재 환경으로 Doctor를 조립해 결과를 반환합니다.
	package func execute(format: CLIOutputFormat) async -> CLIProcessResult {
		let workingDirectoryURL = URL(
			fileURLWithPath: FileManager.default.currentDirectoryPath
		)
		let environment = ProcessInfo.processInfo.environment

		return await execute(
			format: format,
			environmentProvider: SystemDoctorEnvironmentProvider(
				workingDirectoryURL: workingDirectoryURL,
				environment: environment,
				timeout: .seconds(5)
			),
			xcodeBuildMCPReporter: XcodeBuildMCPDoctorReporter(
				workingDirectoryURL: workingDirectoryURL,
				environment: environment,
				timeout: .seconds(5)
			)
		)
	}

	// 주입한 진단 제공자로 Doctor를 조립해 결과를 반환합니다.
	package func execute(
		format: CLIOutputFormat,
		environmentProvider: any DoctorEnvironmentProviding,
		xcodeBuildMCPReporter: any XcodeBuildMCPDoctorReporting
	) async -> CLIProcessResult {
		let doctor = Doctor(
			environmentProvider: environmentProvider,
			xcodeBuildMCPReporter: xcodeBuildMCPReporter
		)
		let report = await doctor.diagnose()

		return QALenzCLIApplication.result(for: report, format: format)
	}
}
