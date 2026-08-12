//
//  QALenzCLI.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import Darwin
import Foundation

@main
enum QALenzCLI {
	static func main() {
		let result = QALenzCLIApplication.execute(
			arguments: Array(CommandLine.arguments.dropFirst())
		)

		write(result.standardOutput, to: .standardOutput)
		write(result.standardError, to: .standardError)
		exit(result.exitStatus.rawValue)
	}

	private static func write(_ value: String?, to handle: FileHandle) {
		guard let value else { return }

		let output = value.hasSuffix("\n") ? value : "\(value)\n"

		handle.write(Data(output.utf8))
	}
}
