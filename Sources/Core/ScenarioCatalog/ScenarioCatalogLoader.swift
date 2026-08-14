//
//  ScenarioCatalogLoader.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// config가 가리키는 directory에서 scenario catalog를 읽습니다.
package struct ScenarioCatalogLoader: ScenarioCatalogLoading {
	// 기본 loader를 구성합니다.
	package init() {}

	// config 파일을 읽고 등록한 scenario의 catalog를 반환합니다.
	package func load(at configurationURL: URL) throws -> ScenarioCatalog {
		let configuration = try QALenzConfigurationDecoder().decode(at: configurationURL)
		let scenarioURLs = try scenarioURLs(in: configuration.scenariosDirectoryURL)
		let result = ScenarioDecoder().decodeResult(at: scenarioURLs)
		let errorsByFilePath = Dictionary(grouping: result.errors, by: \.filePath)
		let entries = result.documents.map { location in
			makeEntry(
				from: location.document,
				filePath: location.url.standardizedFileURL.path,
				errors: errorsByFilePath[location.url.standardizedFileURL.path] ?? []
			)
		} + result.errors.compactMap { error in
			guard !result.documents.contains(where: {
				$0.url.standardizedFileURL.path == error.filePath
			}) else { return nil }

			return .init(
				id: nil,
				name: nil,
				profile: nil,
				filePath: error.filePath,
				status: .invalid,
				errors: errorsByFilePath[error.filePath] ?? []
			)
		}

		return .init(entries: entries.sorted(by: isOrderedBefore))
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

	// 원본 문서와 파일별 오류를 catalog 항목으로 변환합니다.
	private func makeEntry(
		from document: ScenarioDocument,
		filePath: String,
		errors: [ScenarioValidationError]
	) -> ScenarioCatalogEntry {
		.init(
			id: document.id,
			name: document.name,
			profile: document.profile,
			filePath: filePath,
			status: errors.isEmpty ? .valid : .invalid,
			errors: errors
		)
	}

	// id, file path 순서로 catalog 항목의 출력 순서를 결정합니다.
	private func isOrderedBefore(
		_ lhs: ScenarioCatalogEntry,
		_ rhs: ScenarioCatalogEntry
	) -> Bool {
		switch (lhs.id, rhs.id) {
		case let (leftID?, rightID?):
			leftID == rightID ? lhs.filePath < rhs.filePath : leftID < rightID
		case (.some, .none):
			true
		case (.none, .some):
			false
		case (.none, .none):
			lhs.filePath < rhs.filePath
		}
	}
}

// scenario catalog를 읽는 의존성을 정의합니다.
package protocol ScenarioCatalogLoading: Sendable {
	// config 파일 기준 scenario catalog를 반환합니다.
	func load(at configurationURL: URL) throws -> ScenarioCatalog
}
