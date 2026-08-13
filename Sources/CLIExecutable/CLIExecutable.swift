//
//  CLIExecutable.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation
import QALenzCLI

@main
// qalenz 실행 파일의 진입점을 제공합니다.
enum CLIExecutable {
	// CLI 인수를 실행하고 출력과 종료 상태를 전달합니다.
	static func main() async {
		let result = await CLIApplication.execute(
			arguments: Array(CommandLine.arguments.dropFirst())
		)

		write(result.standardOutput, to: .standardOutput)
		write(result.standardError, to: .standardError)
		exit(result.exitStatus.rawValue)
	}

	// 문자열 출력을 파일 핸들에 기록합니다.
	private static func write(_ value: String?, to handle: FileHandle) {
		guard let value else { return }

		let output = value.hasSuffix("\n") ? value : "\(value)\n"

		handle.write(Data(output.utf8))
	}
}
