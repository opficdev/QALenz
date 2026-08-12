//
//  CLIOptions.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser

// CLI 명령의 출력 옵션을 보관합니다.
package struct CLIOptions: ParsableArguments {
	@Option(help: "출력 형식: text 또는 json")
	package var output = CLIOutputFormat.text

	// 기본 출력 옵션으로 초기화합니다.
	package init() {}
}
