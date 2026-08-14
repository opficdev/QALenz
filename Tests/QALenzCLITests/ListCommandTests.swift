//
//  ListCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCLI
@testable import QALenzCore

// qalenz list 명령의 config 경로와 catalog 출력 연결을 검증합니다.
@Suite
struct ListCommandTests {
	// 경로를 생략하면 현재 작업 경로의 고정 config 위치를 읽는지 검증합니다.
	@Test
	func 경로를_생략하면_현재_작업_경로의_config를_읽는다() async throws {
		let loader = ScenarioCatalogLoaderSpy(catalog: .init(entries: []))
		let command = try listCommand()
		let currentDirectoryURL = URL(fileURLWithPath: "/tmp/ListCurrent")

		let result = await command.execute(
			format: .text,
			loader: loader,
			currentDirectoryURL: currentDirectoryURL
		)

		#expect(result.exitStatus == .success)
		#expect(loader.configurationURLs() == [
			currentDirectoryURL
				.appendingPathComponent(".qalenz", isDirectory: true)
				.appendingPathComponent("config.json", isDirectory: false)
		])
	}

	// 일부 오류 catalog를 text와 JSON에서 같은 항목과 실패 종료 상태로 반환하는지 검증합니다.
	@Test
	func 일부_오류_catalog를_text와_JSON으로_반환한다() async throws {
		let catalog = ScenarioCatalog(entries: [
			.init(
				id: "valid",
				name: "Valid",
				profile: "default",
				filePath: "/tmp/valid.json",
				status: .valid,
				errors: []
			),
			.init(
				id: nil,
				name: nil,
				profile: nil,
				filePath: "/tmp/invalid.json",
				status: .invalid,
				errors: [.init(
					code: .jsonInvalid,
					filePath: "/tmp/invalid.json",
					keyPath: "$"
				)]
			)
		])
		let command = try listCommand(path: "/tmp/Project")
		let text = await command.execute(
			format: .text,
			loader: ScenarioCatalogLoaderSpy(catalog: catalog),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let json = await command.execute(
			format: .json,
			loader: ScenarioCatalogLoaderSpy(catalog: catalog),
			currentDirectoryURL: URL(fileURLWithPath: "/tmp")
		)
		let data = try #require(json.standardOutput?.data(using: .utf8))

		#expect(text.exitStatus == .verificationFailure)
		#expect(json.exitStatus == text.exitStatus)
		#expect(try #require(text.standardOutput).contains("[invalid]"))
		#expect(try JSONDecoder().decode(ScenarioCatalog.self, from: data) == catalog)
		#expect(text.standardError == nil)
		#expect(json.standardError == nil)
	}

	// list 하위 명령의 출력 옵션이 루트 옵션보다 우선하는지 검증합니다.
	@Test
	func list_출력_옵션은_루트_옵션보다_우선한다() throws {
		let rootArguments = ["--output", "json", "list"]
		let commandArguments = ["--output", "json", "list", "--output", "text"]
		let rootCommand = try RootCommand.parseAsRoot(rootArguments)
		let commandCommand = try RootCommand.parseAsRoot(commandArguments)
		let rootList = try #require(rootCommand as? ListCommand)
		let commandList = try #require(commandCommand as? ListCommand)

		#expect(CLIApplication.listOutputFormat(
			arguments: rootArguments,
			command: rootList
		) == .json)
		#expect(CLIApplication.listOutputFormat(
			arguments: commandArguments,
			command: commandList
		) == .text)
	}

	// list 명령을 지정한 위치 인수로 해석합니다.
	private func listCommand(path: String? = nil) throws -> ListCommand {
		var arguments = ["list"]

		if let path {
			arguments.append(path)
		}

		let command = try RootCommand.parseAsRoot(arguments)

		return try #require(command as? ListCommand)
	}
}

// 고정 catalog와 요청 config 경로를 기록하는 시험 대역입니다.
private final class ScenarioCatalogLoaderSpy: ScenarioCatalogLoading, @unchecked Sendable {
	private let catalog: ScenarioCatalog
	private let lock = NSLock()
	private var receivedConfigurationURLs = [URL]()

	// 반환할 고정 catalog로 시험 대역을 구성합니다.
	init(catalog: ScenarioCatalog) {
		self.catalog = catalog
	}

	// 요청 config 경로를 기록하고 고정 catalog를 반환합니다.
	func load(at configurationURL: URL) throws -> ScenarioCatalog {
		lock.lock()
		defer { lock.unlock() }
		receivedConfigurationURLs.append(configurationURL)

		return catalog
	}

	// 기록한 config 경로를 반환합니다.
	func configurationURLs() -> [URL] {
		lock.lock()
		defer { lock.unlock() }

		return receivedConfigurationURLs
	}
}
