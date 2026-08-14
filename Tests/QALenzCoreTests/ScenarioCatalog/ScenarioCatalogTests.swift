//
//  ScenarioCatalogTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// ScenarioCatalog의 파일 탐색과 검증 상태 집계를 검증합니다.
@Suite
struct ScenarioCatalogTests {
	// 정상 scenario와 검증 오류 scenario를 파일별 상태로 함께 반환하는지 검증합니다.
	@Test
	func 정상과_오류_scenario를_함께_반환한다() throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		let scenariosURL = projectURL.appendingPathComponent("scenarios", isDirectory: true)
		try FileManager.default.createDirectory(at: scenariosURL, withIntermediateDirectories: true)
		try writeConfiguration(at: projectURL)
		try writeScenario(
			id: "zebra",
			name: "Zebra",
			profile: "default",
			to: scenariosURL.appendingPathComponent("zebra.json")
		)
		try Data("{\"schemaVersion\": 1}".utf8).write(
			to: scenariosURL.appendingPathComponent("broken.json")
		)

		let catalog = try ScenarioCatalogLoader().load(at: configurationURL(in: projectURL))

		#expect(catalog.result == .failed)
		#expect(catalog.entries.map(\.id) == ["zebra", nil])
		#expect(catalog.entries.map(\.status) == [.valid, .invalid])
		#expect(catalog.entries[1].errors == brokenScenarioErrors(
			at: scenariosURL.appendingPathComponent("broken.json")
		))
	}

	// 중복 id가 있는 양쪽 scenario를 오류 상태로 반환하는지 검증합니다.
	@Test
	func 중복_id의_양쪽_scenario를_오류로_반환한다() throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		let scenariosURL = projectURL.appendingPathComponent("scenarios", isDirectory: true)
		try FileManager.default.createDirectory(at: scenariosURL, withIntermediateDirectories: true)
		try writeConfiguration(at: projectURL)
		try writeScenario(
			id: "duplicate",
			name: "First",
			profile: "default",
			to: scenariosURL.appendingPathComponent("first.json")
		)
		try writeScenario(
			id: "duplicate",
			name: "Second",
			profile: "default",
			to: scenariosURL.appendingPathComponent("second.json")
		)

		let catalog = try ScenarioCatalogLoader().load(at: configurationURL(in: projectURL))

		#expect(catalog.entries.map(\.status) == [.invalid, .invalid])
		#expect(catalog.entries.allSatisfy {
			$0.errors.map(\.code) == [.idDuplicate]
		})
	}

	// 바로 아래 JSON 파일만 읽고 하위 directory와 다른 확장자를 제외하는지 검증합니다.
	@Test
	func 바로_아래_JSON_파일만_읽는다() throws {
		let projectURL = try makeProjectDirectory()
		defer { try? FileManager.default.removeItem(at: projectURL) }
		let scenariosURL = projectURL.appendingPathComponent("scenarios", isDirectory: true)
		let nestedURL = scenariosURL.appendingPathComponent("nested", isDirectory: true)
		try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
		try writeConfiguration(at: projectURL)
		try writeScenario(
			id: "direct",
			name: "Direct",
			profile: "default",
			to: scenariosURL.appendingPathComponent("direct.json")
		)
		try writeScenario(
			id: "nested",
			name: "Nested",
			profile: "default",
			to: nestedURL.appendingPathComponent("nested.json")
		)
		try Data("ignored".utf8).write(to: scenariosURL.appendingPathComponent("note.txt"))

		let catalog = try ScenarioCatalogLoader().load(at: configurationURL(in: projectURL))

		#expect(catalog.result == .passed)
		#expect(catalog.entries.map(\.id) == ["direct"])
	}

	// 임시 project directory를 구성합니다.
	private func makeProjectDirectory() throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

		return url
	}

	// project directory 안의 고정 config 위치를 반환합니다.
	private func configurationURL(in projectURL: URL) -> URL {
		projectURL
			.appendingPathComponent(".qalenz", isDirectory: true)
			.appendingPathComponent("config.json", isDirectory: false)
	}

	// scenarios directory를 가리키는 config 파일을 기록합니다.
	private func writeConfiguration(at projectURL: URL) throws {
		let url = configurationURL(in: projectURL)
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "projectRoot": ".",
			  "xcodeBuildMCPProfile": "default",
			  "scenariosDirectory": "../scenarios"
			}
			""".utf8
		).write(to: url)
	}

	// 최소 유효 scenario JSON을 기록합니다.
	private func writeScenario(
		id: String,
		name: String,
		profile: String,
		to url: URL
	) throws {
		try Data(
			"""
			{
			  "schemaVersion": 1,
			  "id": "\(id)",
			  "name": "\(name)",
			  "profile": "\(profile)",
			  "matrix": {},
			  "steps": [{"id": "launch", "action": "buildAndRun"}],
			  "assertions": [],
			  "evidence": []
			}
			""".utf8
		).write(to: url)
	}

	// 필수 scenario key가 없는 파일에서 기대하는 오류를 반환합니다.
	private func brokenScenarioErrors(at url: URL) -> [ScenarioValidationError] {
		["id", "name", "profile", "matrix", "steps", "assertions", "evidence"].map {
			.init(code: .keyMissing, filePath: url.path, keyPath: "$.\($0)")
		}
	}
}
