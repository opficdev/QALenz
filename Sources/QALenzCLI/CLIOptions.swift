//
//  CLIOptions.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser

package struct CLIOptions: ParsableArguments {
	@Option(help: "출력 형식: text 또는 json")
	package var output = CLIOutputFormat.text

	package init() {}
}
