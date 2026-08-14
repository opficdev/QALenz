//
//  RootCommandTests.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser
import Testing
@testable import QALenzCLI

@Suite
struct RootCommandTests {
	@Test
	func 도움말_요청은_도움말을_포함하고_success로_종료한다() throws {
		let error = try #require(caughtError(for: ["--help"]))

		#expect(RootCommand.exitCode(for: error) == .success)
		#expect(RootCommand.fullMessage(for: error).contains("qalenz"))
	}

	@Test
	func 버전_요청은_CLIVersion_current를_반환하고_success로_종료한다() throws {
		let error = try #require(caughtError(for: ["--version"]))

		#expect(RootCommand.exitCode(for: error) == .success)
		#expect(RootCommand.fullMessage(for: error) == CLIVersion.current)
	}

	@Test
	func JSON_출력_옵션은_CLIOutputFormat_json으로_해석된다() throws {
		let command = try RootCommand.parse(["--output", "json"])

		#expect(command.options.output == .json)
	}

	// discover 하위 명령의 선택 경로와 출력 옵션을 해석하는지 검증합니다.
	@Test
	func discover_하위_명령의_경로와_출력_옵션을_해석한다() throws {
		let command = try RootCommand.parseAsRoot([
			"discover", "FixtureProject", "--output", "json"
		])
		let discover = try #require(command as? DiscoverCommand)

		#expect(discover.path == "FixtureProject")
		#expect(discover.options.output == .json)
	}

	// 인수 없는 discover 하위 명령을 해석하는지 검증합니다.
	@Test
	func 경로_없이_discover_하위_명령을_해석한다() throws {
		let command = try RootCommand.parseAsRoot(["discover"])
		let discover = try #require(command as? DiscoverCommand)

		#expect(discover.path == nil)
	}

	// 명령 인수 실행 오류를 반환합니다.
	private func caughtError(for arguments: [String]) -> (any Error)? {
		do {
			var command = try RootCommand.parseAsRoot(arguments)
			try command.run()

			return nil
		} catch {
			return error
		}
	}
}
