//
//  ScenarioDecoder.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// scenario JSON을 검증된 Scenario 값으로 변환합니다.
package struct ScenarioDecoder: Sendable {
	// 기본 decoder를 구성합니다.
	package init() {}

	// 하나의 scenario 파일을 해석하고 검증합니다.
	package func decode(at scenarioURL: URL) throws -> [Scenario] {
		try decode(at: [scenarioURL])
	}

	// 주어진 순서의 scenario 파일을 해석하고 collection 수준의 id 중복까지 검증합니다.
	package func decode(at scenarioURLs: [URL]) throws -> [Scenario] {
		var sources = [ScenarioDataSource]()
		var errors = [ScenarioValidationError]()

		for url in scenarioURLs {
			do {
				sources.append(.init(data: try Data(contentsOf: url), url: url))
			} catch {
				errors.append(.init(
					code: .fileUnreadable,
					filePath: url.standardizedFileURL.path,
					keyPath: "$"
				))
			}
		}

		return try decode(sources, initialErrors: errors)
	}

	// 메모리에 있는 scenario JSON을 지정한 파일 문맥으로 해석하고 검증합니다.
	package func decode(_ data: Data, at scenarioURL: URL) throws -> [Scenario] {
		try decode([.init(data: data, url: scenarioURL)], initialErrors: [])
	}

	// JSON 해석 오류와 의미 검증 오류를 하나의 오류 집합으로 반환합니다.
	private func decode(
		_ sources: [ScenarioDataSource],
		initialErrors: [ScenarioValidationError]
	) throws -> [Scenario] {
		var errors = initialErrors
		var locations = [ScenarioDocumentLocation]()

		for source in sources {
			do {
				let document = try ScenarioJSONDecoder().decode(source.data)
				locations.append(.init(document: document, url: source.url))
			} catch {
				errors.append(decodingError(for: error, scenarioURL: source.url))
			}
		}

		let result = ScenarioValidator().validate(locations)
		errors.append(contentsOf: result.errors)

		guard errors.isEmpty else {
			throw ScenarioValidationErrors(errors: errors)
		}

		return result.scenarios
	}

	// Scenario JSON 해석 오류를 scenario 오류 계약으로 정규화합니다.
	private func decodingError(
		for error: any Error,
		scenarioURL: URL
	) -> ScenarioValidationError {
		if let error = error as? ScenarioJSONDecodingError {
			return .init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: error.keyPath
			)
		}

		guard let error = error as? DecodingError else {
			return .init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$"
			)
		}

		switch error {
		case .keyNotFound(let key, let context):
			return .init(
				code: .keyMissing,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: keyPath(for: context.codingPath + [key])
			)
		case .typeMismatch(_, let context),
			.valueNotFound(_, let context),
			.dataCorrupted(let context):
			return .init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: keyPath(for: context.codingPath)
			)
		@unknown default:
			return .init(
				code: .jsonInvalid,
				filePath: scenarioURL.standardizedFileURL.path,
				keyPath: "$"
			)
		}
	}

	// JSON coding path를 array index를 보존한 JSONPath 문자열로 변환합니다.
	private func keyPath(for codingPath: [any CodingKey]) -> String {
		codingPath.reduce(into: "$") { path, key in
			if let index = key.intValue {
				path += "[\(index)]"
			} else {
				path += ".\(key.stringValue)"
			}
		}
	}
}

// decoder가 JSON data와 원본 파일 위치를 함께 다루는 내부 값입니다.
private struct ScenarioDataSource {
	let data: Data
	let url: URL
}
