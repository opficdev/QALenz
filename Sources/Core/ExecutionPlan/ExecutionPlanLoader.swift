//
//  ExecutionPlanLoader.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// config와 scenario 파일에서 dry-run 실행 계획을 읽는 의존성을 정의합니다.
package protocol ExecutionPlanLoading: Sendable {
	// configurationURL과 scenario 식별자로 실행 계획을 반환합니다.
	func load(scenarioID: String, at configurationURL: URL) throws -> ExecutionPlan
}

// config가 가리키는 scenario에서 실행 계획을 구성합니다.
package struct ExecutionPlanLoader: ExecutionPlanLoading {
	// 기본 loader를 구성합니다.
	package init() {}

	// 설정과 scenario를 읽어 지정한 식별자의 실행 계획을 반환합니다.
	package func load(scenarioID: String, at configurationURL: URL) throws -> ExecutionPlan {
		let configuration = try QALenzConfigurationDecoder().decode(at: configurationURL)
		let scenarioURLs = try scenarioURLs(in: configuration.scenariosDirectoryURL)
		let scenarios = try ScenarioDecoder().decode(at: scenarioURLs)
		guard let scenario = scenarios.first(where: { $0.id == scenarioID }) else {
			throw RunError(
				kind: .configuration,
				code: .init(rawValue: "configuration.scenario.not-found"),
				context: .init(filePath: configuration.scenariosDirectoryURL.path)
			)
		}

		return try ExecutionPlanBuilder().build(
			scenario: scenario,
			configuration: configuration
		)
	}

	// scenarios directory 바로 아래의 일반 JSON 파일을 정렬해 반환합니다.
	private func scenarioURLs(in directoryURL: URL) throws -> [URL] {
		do {
			return try FileManager.default.contentsOfDirectory(
				at: directoryURL,
				includingPropertiesForKeys: [.isRegularFileKey],
				options: [.skipsHiddenFiles]
			).filter { url in
				let values = try? url.resourceValues(forKeys: [.isRegularFileKey])

				return url.pathExtension == "json" && values?.isRegularFile == true
			}.sorted { $0.path < $1.path }
		} catch {
			throw RunError(
				kind: .configuration,
				code: .init(rawValue: "configuration.scenarios-directory.unreadable"),
				context: .init(
					filePath: directoryURL.standardizedFileURL.path,
					keyPath: "$.scenariosDirectory"
				)
			)
		}
	}
}
