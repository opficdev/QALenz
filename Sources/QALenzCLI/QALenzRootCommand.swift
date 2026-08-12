//
//  QALenzRootCommand.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser

package struct QALenzRootCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "qalenz",
		abstract: "여러 iOS 프로젝트의 Simulator QA 실행을 조율합니다.",
		version: CLIVersion.current
	)
	@OptionGroup
	package var options: CLIOptions

	package init() {}
}
