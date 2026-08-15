//
//  QALenzConfigurationDecoderTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation
import Testing
@testable import QALenzCore

// QALenzConfigurationDecoder의 JSON 해석과 경로 정규화 계약을 검증합니다.
@Suite
struct QALenzConfigurationDecoderTests {
	private let applicationSupportDirectoryURL = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString, isDirectory: true)

	// 상대 경로가 config 파일을 기준으로 정규화되는지 검증합니다.
	@Test
	func 유효한_config의_상대_경로를_파일_기준으로_정규화한다() throws {
		let configurationURL = try fixtureURL(named: "valid")
		let configuration = try makeDecoder().decode(at: configurationURL)
		let baseURL = configurationURL.deletingLastPathComponent()

		#expect(configuration.schemaVersion == 1)
		#expect(configuration.projectRootURL == baseURL
			.appendingPathComponent("..", isDirectory: true)
			.standardizedFileURL)
		#expect(configuration.xcodeBuildMCPProfile == "default")
		#expect(configuration.scenariosDirectoryURL == baseURL
			.appendingPathComponent("scenarios", isDirectory: true)
			.standardizedFileURL)
		#expect(configuration.outputDirectoryURL == baseURL
			.appendingPathComponent("outputs", isDirectory: true)
			.standardizedFileURL)
		#expect(configuration.targetDefaults == .init(
			devices: ["iPhone 16"],
			operatingSystems: ["iOS 26.0"],
			appearances: ["light"]
		))
		#expect(configuration.targetPolicy.maximumTargetCount == 12)
	}

	// outputDirectory가 없으면 repository 밖의 기본 경로를 반환하는지 검증합니다.
	@Test
	func outputDirectory가_없으면_Application_Support의_run_저장_경로를_반환한다() throws {
		let configurationURL = try fixtureURL(named: "default-output-directory")
		let configuration = try makeDecoder().decode(at: configurationURL)
		let expectedURL = applicationSupportDirectoryURL
			.appendingPathComponent("QALenz", isDirectory: true)
			.appendingPathComponent("Runs", isDirectory: true)
			.standardizedFileURL

		#expect(configuration.outputDirectoryURL == expectedURL)
		#expect(!FileManager.default.fileExists(atPath: expectedURL.path))
	}

	// outputDirectory가 null이면 Schema와 같은 설정 오류로 거부하는지 검증합니다.
	@Test
	func outputDirectory가_null이면_설정_오류로_거부한다() throws {
		let configurationURL = try fixtureURL(named: "null-output-directory")
		let error = try requireConfigurationError {
			try makeDecoder().decode(at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.json.invalid")
		#expect(error.context.filePath == configurationURL.standardizedFileURL.path)
		#expect(error.context.keyPath == "$.outputDirectory")
	}

	// 읽을 수 없는 config 파일이 파일 경로와 root key path를 보존하는지 검증합니다.
	@Test
	func 읽을_수_없는_config_파일은_설정_오류로_거부한다() throws {
		let configurationURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let error = try requireConfigurationError {
			try makeDecoder().decode(at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.file.unreadable")
		#expect(error.context.filePath == configurationURL.standardizedFileURL.path)
		#expect(error.context.keyPath == "$")
	}

	// 구문이 잘못된 JSON이 파일 경로와 root key path를 보존하는지 검증합니다.
	@Test
	func 구문이_잘못된_JSON은_설정_오류로_거부한다() throws {
		let configurationURL = URL(fileURLWithPath: "/tmp/Project/.qalenz/config.json")
		let error = try requireConfigurationError {
			try makeDecoder().decode(Data("{".utf8), at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.json.invalid")
		#expect(error.context.filePath == configurationURL.path)
		#expect(error.context.keyPath == "$")
	}

	// 지원하지 않는 schemaVersion이 설정 오류와 JSON key path로 거부되는지 검증합니다.
	@Test
	func 지원하지_않는_schemaVersion은_설정_오류로_거부한다() throws {
		let configurationURL = try fixtureURL(named: "unsupported-schema-version")
		let error = try requireConfigurationError {
			try makeDecoder().decode(at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.schema.unsupported")
		#expect(error.context.filePath == configurationURL.standardizedFileURL.path)
		#expect(error.context.keyPath == "$.schemaVersion")
	}

	// 필수 JSON key 누락이 설정 오류와 JSON key path로 거부되는지 검증합니다.
	@Test
	func 필수_JSON_key_누락은_설정_오류로_거부한다() throws {
		let configurationURL = try fixtureURL(named: "missing-xcodebuildmcp-profile")
		let error = try requireConfigurationError {
			try makeDecoder().decode(at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.key.missing")
		#expect(error.context.filePath == configurationURL.standardizedFileURL.path)
		#expect(error.context.keyPath == "$.xcodeBuildMCPProfile")
	}

	// JSON 값의 형식 불일치가 설정 오류와 JSON key path로 거부되는지 검증합니다.
	@Test
	func JSON_값의_형식_불일치는_설정_오류로_거부한다() throws {
		let configurationURL = try fixtureURL(named: "invalid-scenarios-directory")
		let error = try requireConfigurationError {
			try makeDecoder().decode(at: configurationURL)
		}

		#expect(error.kind == .configuration)
		#expect(error.code.rawValue == "configuration.json.invalid")
		#expect(error.context.filePath == configurationURL.standardizedFileURL.path)
		#expect(error.context.keyPath == "$.scenariosDirectory")
	}

	// target 설정의 schema 의미 제약을 decoder 경계에서 거부하는지 검증합니다.
	@Test
	func target_설정의_의미_제약을_거부한다() throws {
		let cases = [
			("\"devices\": []", "$.targetDefaults.devices"),
			("\"devices\": [\"   \"]", "$.targetDefaults.devices"),
			("\"maximumTargetCount\": 0", "$.maximumTargetCount"),
			(
				"\"targetDefaults\": {\"devices\": [\"iPhone 16\"], \"operatingSystems\": [\"iOS 26.0\"], " +
					"\"appearances\": [\"light\"], \"unknown\": []}",
				"$.targetDefaults.unknown"
			)
		]

		for (replacement, keyPath) in cases {
			let data = Data(configurationJSON(replacing: replacement).utf8)
			let error = try requireConfigurationError {
				try makeDecoder().decode(data, at: URL(fileURLWithPath: "/tmp/config.json"))
			}

			#expect(error.code.rawValue == "configuration.value.invalid")
			#expect(error.context.keyPath == keyPath)
		}
	}

	// 고정된 Application Support 경로를 주입한 decoder를 구성합니다.
	private func makeDecoder() -> QALenzConfigurationDecoder {
		.init(applicationSupportDirectoryURL: applicationSupportDirectoryURL)
	}

	// 이름에 해당하는 JSON fixture의 URL을 반환합니다.
	private func fixtureURL(named name: String) throws -> URL {
		try #require(
			Bundle.module.url(
				forResource: name,
				withExtension: "json",
				subdirectory: "Fixtures/Configuration"
			)
		)
	}

	// decoder가 던진 설정 오류를 반환합니다.
	private func requireConfigurationError(
		from operation: () throws -> QALenzConfiguration
	) throws -> RunError {
		try #require(throws: RunError.self) {
			try operation()
		}
	}

	// target 설정 일부를 치환한 유효 config JSON을 반환합니다.
	private func configurationJSON(replacing replacement: String) -> String {
		let defaults = "\"targetDefaults\": {\"devices\": [\"iPhone 16\"], " +
			"\"operatingSystems\": [\"iOS 26.0\"], \"appearances\": [\"light\"]}"
		let maximum = "\"maximumTargetCount\": 12"
		let values = if replacement.hasPrefix("\"maximumTargetCount\"") {
			"\(defaults), \(replacement)"
		} else if replacement.hasPrefix("\"targetDefaults\"") {
			"\(replacement), \(maximum)"
		} else {
			"\"targetDefaults\": {\(replacement), \"operatingSystems\": [\"iOS 26.0\"], \"appearances\": [\"light\"]}, \(maximum)"
		}

		return """
		{
		  "schemaVersion": 1,
		  "projectRoot": ".",
		  "xcodeBuildMCPProfile": "default",
		  "scenariosDirectory": "scenarios",
		  \(values)
		}
		"""
	}
}
