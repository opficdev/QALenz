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
		guard let commandName = DoctorCommand.configuration.commandName,
			let commandIndex = arguments.firstIndex(of: commandName) else {
			return command.options.output
		}

		let commandArguments = arguments.suffix(
			from: arguments.index(after: commandIndex)
		)
		guard !containsOutputOption(in: commandArguments) else {
			return command.options.output
		}

		return CLIOutputFormat.requested(in: Array(arguments[..<commandIndex]))
	}

	// doctor 사용 오류에서 root와 하위 명령 옵션의 우선순위를 반환합니다.
	private static func usageErrorOutputFormat(in arguments: [String]) -> CLIOutputFormat {
		let parsingArguments = arguments.prefix { $0 != "--" }
		guard let commandName = DoctorCommand.configuration.commandName else {
			return CLIOutputFormat.requested(in: arguments)
		}
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

			guard argument == commandName else {
				return CLIOutputFormat.requested(in: arguments)
			}

			let commandArguments = parsingArguments.suffix(from: parsingArguments.index(after: index))

			return explicitOutputFormat(in: commandArguments) ?? CLIOutputFormat.requested(in: Array(parsingArguments[..<index]))
		}

		return CLIOutputFormat.requested(in: arguments)
	}

	// DoctorReport를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for report: DoctorReport,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: textOutput(for: report),
				standardError: nil,
				exitStatus: .init(result: report.result)
			)
		case .json:
			return jsonResult(for: report)
		}
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

	// DoctorReport를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for report: DoctorReport) -> CLIProcessResult {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(report)

			return .init(
				// swiftlint:disable:next optional_data_string_conversion
				standardOutput: String(decoding: data, as: UTF8.self),
				standardError: nil,
				exitStatus: .init(result: report.result)
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Doctor report encoding failed.",
				exitStatus: .executionError
			)
		}
	}

	// DoctorReport의 항목을 사람이 읽을 수 있는 줄 단위 출력으로 변환합니다.
	private static func textOutput(for report: DoctorReport) -> String {
		var lines = report.diagnostics.map { diagnostic in
			let recommendation = diagnostic.recommendation.map { "\n  \($0)" } ?? ""

			return "[\(diagnostic.status.rawValue)] [\(diagnostic.requirement.rawValue)] \(diagnostic.id.rawValue): \(diagnostic.message)\(recommendation)"
		}

		if case let .errored(error) = report.result {
			lines.append("[errored] [\(error.kind.rawValue)] \(error.code.rawValue)")
		}

		return lines.joined(separator: "\n")
	}
}
