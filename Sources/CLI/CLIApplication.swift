//
//  CLIApplication.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser
import Foundation
import QALenzCore

// CLI 인수를 처리해 프로세스 결과로 변환합니다.
package enum CLIApplication {
	// CLI 인수를 실행해 프로세스 결과를 만듭니다.
	package static func execute(arguments: [String]) async -> CLIProcessResult {
		let format = usageErrorOutputFormat(in: arguments)

		do {
			let parsedCommand = try RootCommand.parseAsRoot(arguments)

			if let doctorCommand = parsedCommand as? DoctorCommand {
				return await doctorCommand.execute(
					format: doctorOutputFormat(
						arguments: arguments,
						command: doctorCommand
					)
				)
			}

			if let discoverCommand = parsedCommand as? DiscoverCommand {
				return await discoverCommand.execute(
					format: discoverOutputFormat(
						arguments: arguments,
						command: discoverCommand
					)
				)
			}

			var command = parsedCommand
			try command.run()

			return .init(standardOutput: nil, standardError: nil, exitStatus: .success)
		} catch {
			return result(for: error, format: format)
		}
	}

	// root와 doctor 옵션의 우선순위에 맞는 출력 형식을 반환합니다.
	package static func doctorOutputFormat(
		arguments: [String],
		command: DoctorCommand
	) -> CLIOutputFormat {
		outputFormat(
			arguments: arguments,
			commandName: DoctorCommand.configuration.commandName,
			commandOutputFormat: command.options.output
		)
	}

	// root와 discover 옵션의 우선순위에 맞는 출력 형식을 반환합니다.
	package static func discoverOutputFormat(
		arguments: [String],
		command: DiscoverCommand
	) -> CLIOutputFormat {
		outputFormat(
			arguments: arguments,
			commandName: DiscoverCommand.configuration.commandName,
			commandOutputFormat: command.options.output
		)
	}

	// doctor 사용 오류에서 root와 하위 명령 옵션의 우선순위를 반환합니다.
	private static func usageErrorOutputFormat(in arguments: [String]) -> CLIOutputFormat {
		let parsingArguments = arguments.prefix { $0 != "--" }
		let commandNames = [
			DoctorCommand.configuration.commandName,
			DiscoverCommand.configuration.commandName
		].compactMap { $0 }
		var index = parsingArguments.startIndex

		while index != parsingArguments.endIndex {
			let argument = parsingArguments[index]

			if argument == "--output" {
				let valueIndex = parsingArguments.index(after: index)
				guard parsingArguments.indices.contains(valueIndex) else {
					return CLIOutputFormat.requested(in: arguments)
				}

				index = parsingArguments.index(after: valueIndex)
				continue
			}

			if argument.hasPrefix("--output=") {
				index = parsingArguments.index(after: index)
				continue
			}

			guard commandNames.contains(argument) else {
				return CLIOutputFormat.requested(in: arguments)
			}

			let commandArguments = parsingArguments.suffix(from: parsingArguments.index(after: index))

			return explicitOutputFormat(in: commandArguments) ?? CLIOutputFormat.requested(in: Array(parsingArguments[..<index]))
		}

		return CLIOutputFormat.requested(in: arguments)
	}

	// root와 하위 명령 옵션의 우선순위에 맞는 출력 형식을 반환합니다.
	private static func outputFormat(
		arguments: [String],
		commandName: String?,
		commandOutputFormat: CLIOutputFormat
	) -> CLIOutputFormat {
		guard let commandName,
			let commandIndex = arguments.firstIndex(of: commandName) else {
			return commandOutputFormat
		}

		let commandArguments = arguments.suffix(
			from: arguments.index(after: commandIndex)
		)
		guard !containsOutputOption(in: commandArguments) else {
			return commandOutputFormat
		}

		return CLIOutputFormat.requested(in: Array(arguments[..<commandIndex]))
	}

	// 파싱 오류를 출력 형식에 맞는 프로세스 결과로 변환합니다.
	private static func result(
		for error: any Error,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		let fullMessage = RootCommand.fullMessage(for: error)

		guard RootCommand.exitCode(for: error) != .success else {
			return .init(
				standardOutput: fullMessage,
				standardError: nil,
				exitStatus: .success
			)
		}

		let usageError = CLIUsageError(
			message: RootCommand.message(for: error),
			usage: usage(in: fullMessage)
		)

		switch format {
		case .text:
			return .init(
				standardOutput: nil,
				standardError: fullMessage,
				exitStatus: .usageError
			)
		case .json:
			return jsonResult(for: usageError)
		}
	}

	// ArgumentParser가 보존한 명령 문맥의 usage를 반환합니다.
	private static func usage(in fullMessage: String) -> String {
		guard let usageLine = fullMessage.split(separator: "\n").first(
			where: { $0.hasPrefix("Usage: ") }
		) else {
			return RootCommand.usageString(for: RootCommand.self)
		}

		return String(usageLine.dropFirst("Usage: ".count))
	}

	// 인수 구간에 출력 옵션이 명시됐는지 반환합니다.
	private static func containsOutputOption(
		in arguments: ArraySlice<String>
	) -> Bool {
		for argument in arguments {
			if argument == "--" {
				return false
			}

			if argument == "--output" || argument.hasPrefix("--output=") {
				return true
			}
		}

		return false
	}

	// 인수 구간에 유효한 출력 옵션이 명시됐으면 반환합니다.
	private static func explicitOutputFormat(in arguments: ArraySlice<String>) -> CLIOutputFormat? {
		for index in arguments.indices {
			let argument = arguments[index]

			if argument.hasPrefix("--output=") {
				return .init(rawValue: String(argument.dropFirst("--output=".count)))
			}

			guard argument == "--output" else {
				continue
			}

			let valueIndex = arguments.index(after: index)
			guard arguments.indices.contains(valueIndex) else {
				return nil
			}

			return .init(rawValue: arguments[valueIndex])
		}

		return nil
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
