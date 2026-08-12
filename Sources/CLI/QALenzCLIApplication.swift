//
//  QALenzCLIApplication.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser
import Foundation

// CLI 인수를 처리해 프로세스 결과로 변환합니다.
package enum QALenzCLIApplication {
	// CLI 인수를 실행해 프로세스 결과를 만듭니다.
	package static func execute(arguments: [String]) -> CLIProcessResult {
		let format = CLIOutputFormat.requested(in: arguments)

		do {
			var command = try QALenzRootCommand.parseAsRoot(arguments)
			try command.run()

			return .init(
				standardOutput: nil,
				standardError: nil,
				exitStatus: .success
			)
		} catch {
			return result(for: error, format: format)
		}
	}

	// 파싱 오류를 출력 형식에 맞는 프로세스 결과로 변환합니다.
	private static func result(
		for error: any Error,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		guard QALenzRootCommand.exitCode(for: error) != .success else {
			return .init(
				standardOutput: QALenzRootCommand.fullMessage(for: error),
				standardError: nil,
				exitStatus: .success
			)
		}

		let usageError = CLIUsageError(
			message: QALenzRootCommand.message(for: error),
			usage: QALenzRootCommand.usageString(for: QALenzRootCommand.self)
		)

		switch format {
		case .text:
			return .init(
				standardOutput: nil,
				standardError: QALenzRootCommand.fullMessage(for: error),
				exitStatus: .usageError
			)
		case .json:
			return jsonResult(for: usageError)
		}
	}

	// CLIUsageError를 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for error: CLIUsageError) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.sortedKeys]
			let data = try encoder.encode(error)

			return .init(
				standardOutput: nil,
				// swiftlint:disable:next optional_data_string_conversion
				standardError: String(decoding: data, as: UTF8.self),
				exitStatus: .usageError
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "CLI usage error encoding failed.",
				exitStatus: .executionError
			)
		}
	}
}
