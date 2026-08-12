//
//  QALenzCLIExecutable.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation
import QALenzCLI

// QALenz CLI process의 진입점과 표준 출력을 관리합니다.
@main
enum QALenzCLIExecutable {
	// argument를 처리하고 결과와 종료 상태를 process에 반영합니다.
	static func main() {
		let result = QALenzCLIApplication.execute(
			arguments: Array(CommandLine.arguments.dropFirst())
		)

		write(result.standardOutput, to: .standardOutput)
		write(result.standardError, to: .standardError)
		exit(result.exitStatus.rawValue)
	}

	// 문자열 끝에 줄바꿈을 보장해 지정된 handle로 출력합니다.
	private static func write(_ value: String?, to handle: FileHandle) {
		guard let value else { return }

		let output = value.hasSuffix("\n") ? value : "\(value)\n"

		handle.write(Data(output.utf8))
	}
}
