//
//  DiscoverCommand.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import ArgumentParser

// 실행 대상 후보 조회 명령의 인수와 옵션을 정의합니다.
package struct DiscoverCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "discover",
		abstract: "실행 대상 후보를 조회합니다."
	)
	@Argument(help: "조회할 project 경로")
	package var path: String?
	@OptionGroup
	package var options: CLIOptions

	// 기본 인수와 출력 옵션으로 초기화합니다.
	package init() {}
}
