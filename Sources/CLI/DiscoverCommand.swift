//
//  DiscoverCommand.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import ArgumentParser
import Foundation
import QALenzCore
import QALenzXcodeBuildMCP

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

	// 현재 환경으로 실행 대상 후보를 조회합니다.
	package func execute() async -> CLIProcessResult {
		await execute(format: options.output)
	}

	// 요청한 출력 형식과 현재 환경으로 실행 대상 후보를 조회합니다.
	package func execute(format: CLIOutputFormat) async -> CLIProcessResult {
		let currentDirectoryURL = URL(
			fileURLWithPath: FileManager.default.currentDirectoryPath
		)
		let adapter = XcodeBuildMCPCLIAdapter(
			workingDirectoryURL: currentDirectoryURL,
			environment: ProcessInfo.processInfo.environment,
			timeout: .seconds(5)
		)

		return await execute(
			format: format,
			adapter: adapter,
			currentDirectoryURL: currentDirectoryURL
		)
	}

	// 주입한 adapter로 실행 대상 후보를 조회합니다.
	package func execute(
		format: CLIOutputFormat,
		adapter: any XcodeBuildMCPAdapter,
		currentDirectoryURL: URL
	) async -> CLIProcessResult {
		let provider = XcodeBuildMCPDiscoveryProvider(adapter: adapter)

		return await execute(
			format: format,
			provider: provider,
			currentDirectoryURL: currentDirectoryURL
		)
	}

	// 주입한 discovery provider로 실행 대상 후보를 조회합니다.
	package func execute(
		format: CLIOutputFormat,
		provider: any XcodeBuildMCPDiscoveryProviding,
		currentDirectoryURL: URL
	) async -> CLIProcessResult {
		let rootURL = rootURL(relativeTo: currentDirectoryURL)

		do {
			let discoveryResult = try await provider.discover(at: rootURL)

			return CLIApplication.result(for: discoveryResult, format: format)
		} catch {
			return CLIApplication.result(
				for: runError(for: error),
				format: format
			)
		}
	}

	// 명령 인수와 현재 작업 경로로 조회 기준 경로를 반환합니다.
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

	// 조회 중 발생한 오류를 원문 없이 공통 오류로 정규화합니다.
	private func runError(for error: any Error) -> RunError {
		guard let error = error as? RunError else {
			return .init(
				kind: .execution,
				code: .init(rawValue: "execution.discovery.failed"),
				context: .init(command: "discover")
			)
		}

		return error
	}
}
