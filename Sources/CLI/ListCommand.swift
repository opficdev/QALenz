//
//  ListCommand.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import ArgumentParser
import Foundation
import QALenzCore

// 등록한 scenario와 validation 상태를 조회하는 명령의 인수와 옵션을 정의합니다.
package struct ListCommand: ParsableCommand {
	package static let configuration = CommandConfiguration(
		commandName: "list",
		abstract: "등록한 scenario와 검증 상태를 조회합니다."
	)
	@Argument(help: "조회할 project 경로")
	package var path: String?
	@OptionGroup
	package var options: CLIOptions

	// 기본 인수와 출력 옵션으로 초기화합니다.
	package init() {}

	// 현재 환경으로 scenario catalog를 조회합니다.
	package func execute() async -> CLIProcessResult {
		await execute(format: options.output)
	}

	// 요청한 출력 형식과 현재 환경으로 scenario catalog를 조회합니다.
	package func execute(format: CLIOutputFormat) async -> CLIProcessResult {
		await execute(
			format: format,
			loader: ScenarioCatalogLoader(),
			currentDirectoryURL: URL(
				fileURLWithPath: FileManager.default.currentDirectoryPath
			)
		)
	}

	// 주입한 loader로 scenario catalog를 조회합니다.
	package func execute(
		format: CLIOutputFormat,
		loader: any ScenarioCatalogLoading,
		currentDirectoryURL: URL
	) async -> CLIProcessResult {
		let configurationURL = rootURL(relativeTo: currentDirectoryURL)
			.appendingPathComponent(".qalenz", isDirectory: true)
			.appendingPathComponent("config.json", isDirectory: false)

		do {
			let catalog = try loader.load(at: configurationURL)

			return CLIApplication.result(for: catalog, format: format)
		} catch {
			return CLIApplication.result(for: runError(for: error), format: format)
		}
	}

	// 명령 인수와 현재 작업 경로로 project 기준 경로를 반환합니다.
	private func rootURL(relativeTo currentDirectoryURL: URL) -> URL {
		guard let path else {
			return currentDirectoryURL.standardizedFileURL
		}

		let url = URL(fileURLWithPath: path)

		guard url.isFileURL, path.hasPrefix("/") else {
			return currentDirectoryURL
				.appendingPathComponent(path)
				.standardizedFileURL
		}

		return url.standardizedFileURL
	}

	// catalog 조회 중 발생한 오류를 원문 없이 공통 오류로 정규화합니다.
	private func runError(for error: any Error) -> RunError {
		guard let error = error as? RunError else {
			return .init(
				kind: .execution,
				code: .init(rawValue: "execution.list.failed"),
				context: .init(command: "list")
			)
		}

		return error
	}
}
