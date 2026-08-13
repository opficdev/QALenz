//
//  RootCommand.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser

// qalenz 루트 명령과 공통 옵션을 정의합니다.
package struct RootCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "qalenz",
		abstract: "여러 iOS 프로젝트의 Simulator QA 실행을 조율합니다.",
		version: CLIVersion.current,
		subcommands: [DoctorCommand.self]
	)
	@OptionGroup
	package var options: CLIOptions

	// 루트 명령을 기본 옵션으로 초기화합니다.
	package init() {}
}
