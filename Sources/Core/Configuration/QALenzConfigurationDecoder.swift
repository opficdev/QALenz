//
//  QALenzConfigurationDecoder.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// config JSON을 QALenzConfiguration으로 검증하고 정규화합니다.
package struct QALenzConfigurationDecoder: Sendable {
	private let applicationSupportDirectoryURL: URL

	// 기본 run 저장 위치의 상위 경로로 decoder를 구성합니다.
	package init(
		applicationSupportDirectoryURL: URL = FileManager.default.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		)[0]
	) {
		self.applicationSupportDirectoryURL = applicationSupportDirectoryURL
	}

	// 파일의 JSON을 읽어 정규화된 설정으로 변환합니다.
	package func decode(at configurationURL: URL) throws -> QALenzConfiguration {
		let data: Data

		do {
			data = try Data(contentsOf: configurationURL)
		} catch {
			throw configurationError(
				code: "configuration.file.unreadable",
				configurationURL: configurationURL,
				keyPath: "$"
			)
		}

		return try decode(data, at: configurationURL)
	}

	// JSON data를 파일 위치 문맥으로 정규화된 설정으로 변환합니다.
	package func decode(
		_ data: Data,
		at configurationURL: URL
	) throws -> QALenzConfiguration {
		let document: QALenzConfigurationDocument

		do {
			document = try JSONDecoder().decode(
				QALenzConfigurationDocument.self,
				from: data
			)
		} catch {
			throw decodingError(for: error, configurationURL: configurationURL)
		}

		guard document.schemaVersion == QALenzConfiguration.supportedSchemaVersion else {
			throw configurationError(
				code: "configuration.schema.unsupported",
				configurationURL: configurationURL,
				keyPath: "$.schemaVersion"
			)
		}
		try validate(document, configurationURL: configurationURL)

		let outputDirectoryURL = document.outputDirectory.map {
			resolvedURL(for: $0, configurationURL: configurationURL)
		} ?? defaultOutputDirectoryURL

		return .init(
			schemaVersion: document.schemaVersion,
			projectRootURL: resolvedURL(
				for: document.projectRoot,
				configurationURL: configurationURL
			),
			xcodeBuildMCPProfile: document.xcodeBuildMCPProfile,
			scenariosDirectoryURL: resolvedURL(
				for: document.scenariosDirectory,
				configurationURL: configurationURL
			),
			outputDirectoryURL: outputDirectoryURL,
			targetDefaults: document.targetDefaults,
			targetPolicy: .init(maximumTargetCount: document.maximumTargetCount)
		)
	}

	// config 파일 기준으로 절대 또는 상대 경로를 정규화합니다.
	private func resolvedURL(
		for path: String,
		configurationURL: URL
	) -> URL {
		let url = if path.hasPrefix("/") {
			URL(fileURLWithPath: path, isDirectory: true)
		} else {
			configurationURL
				.deletingLastPathComponent()
				.appendingPathComponent(path, isDirectory: true)
		}

		return url.standardizedFileURL
	}

	// outputDirectory가 없을 때 repository 밖의 기본 run 저장 위치를 반환합니다.
	private var defaultOutputDirectoryURL: URL {
		applicationSupportDirectoryURL
			.appendingPathComponent("QALenz", isDirectory: true)
			.appendingPathComponent("Runs", isDirectory: true)
			.standardizedFileURL
	}

	// JSONDecoder 오류를 설정 오류 계약으로 정규화합니다.
	private func decodingError(
		for error: any Error,
		configurationURL: URL
	) -> RunError {
		if let error = error as? ConfigurationValidationError {
			return configurationError(
				code: "configuration.value.invalid",
				configurationURL: configurationURL,
				keyPath: error.keyPath
			)
		}
		guard let error = error as? DecodingError else {
			return configurationError(
				code: "configuration.json.invalid",
				configurationURL: configurationURL,
				keyPath: "$"
			)
		}

		switch error {
		case .keyNotFound(let key, let context):
			return configurationError(
				code: "configuration.key.missing",
				configurationURL: configurationURL,
				keyPath: keyPath(for: context.codingPath + [key])
			)
		case .typeMismatch(_, let context),
			.valueNotFound(_, let context),
			.dataCorrupted(let context):
			return configurationError(
				code: "configuration.json.invalid",
				configurationURL: configurationURL,
				keyPath: keyPath(for: context.codingPath)
			)
		@unknown default:
			return configurationError(
				code: "configuration.json.invalid",
				configurationURL: configurationURL,
				keyPath: "$"
			)
		}
	}

	// 설정 schema의 의미 제약을 JSON key path와 함께 검증합니다.
	private func validate(
		_ document: QALenzConfigurationDocument,
		configurationURL: URL
	) throws {
		for (name, values) in [
			("devices", document.targetDefaults.devices),
			("operatingSystems", document.targetDefaults.operatingSystems),
			("appearances", document.targetDefaults.appearances)
		] {
			guard !values.isEmpty else {
				throw configurationError(
					code: "configuration.value.invalid",
					configurationURL: configurationURL,
					keyPath: "$.targetDefaults.\(name)"
				)
			}

			guard values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
				throw configurationError(
					code: "configuration.value.invalid",
					configurationURL: configurationURL,
					keyPath: "$.targetDefaults.\(name)"
				)
			}
		}

		guard 0 < document.maximumTargetCount else {
			throw configurationError(
				code: "configuration.value.invalid",
				configurationURL: configurationURL,
				keyPath: "$.maximumTargetCount"
			)
		}
	}

	// JSON coding path를 오류 문맥에 사용할 JSONPath 문자열로 변환합니다.
	private func keyPath(for codingPath: [any CodingKey]) -> String {
		guard !codingPath.isEmpty else {
			return "$"
		}

		return "$." + codingPath.map(\.stringValue).joined(separator: ".")
	}

	// 설정 파일 경로와 JSON key path를 포함한 RunError를 구성합니다.
	private func configurationError(
		code: String,
		configurationURL: URL,
		keyPath: String
	) -> RunError {
		.init(
			kind: .configuration,
			code: .init(rawValue: code),
			context: .init(
				filePath: configurationURL.standardizedFileURL.path,
				keyPath: keyPath
			)
		)
	}
}

// JSONDecoder가 해석할 config 파일의 원본 구조를 표현합니다.
package struct QALenzConfigurationDocument: Decodable {
	package static let requiredKeyNames = [
		"schemaVersion",
		"projectRoot",
		"xcodeBuildMCPProfile",
		"scenariosDirectory",
		"targetDefaults",
		"maximumTargetCount"
	]

	package static let keyNames = requiredKeyNames + ["outputDirectory"]

	// config JSON의 key를 decoding에 사용합니다.
	private enum CodingKeys: String, CodingKey {
		case schemaVersion
		case projectRoot
		case xcodeBuildMCPProfile
		case scenariosDirectory
		case outputDirectory
		case targetDefaults
		case maximumTargetCount
	}

	let schemaVersion: Int
	let projectRoot: String
	let xcodeBuildMCPProfile: String
	let scenariosDirectory: String
	let outputDirectory: String?
	let targetDefaults: TargetDefaults
	let maximumTargetCount: Int

	// 필수 key와 선택 key의 JSON 값 형식을 분리해 해석합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
		projectRoot = try container.decode(String.self, forKey: .projectRoot)
		xcodeBuildMCPProfile = try container.decode(
			String.self,
			forKey: .xcodeBuildMCPProfile
		)
		scenariosDirectory = try container.decode(
			String.self,
			forKey: .scenariosDirectory
		)
		targetDefaults = try container.decode(TargetDefaults.self, forKey: .targetDefaults)
		let targetDefaultsContainer = try container.nestedContainer(
			keyedBy: TargetDefaultsCodingKey.self,
			forKey: .targetDefaults
		)
		if let unknownKey = targetDefaultsContainer.allKeys.first(
			where: { !TargetDefaultsCodingKey.allowedNames.contains($0.stringValue) }
		) {
			throw ConfigurationValidationError(
				keyPath: "$.targetDefaults.\(unknownKey.stringValue)"
			)
		}
		maximumTargetCount = try container.decode(Int.self, forKey: .maximumTargetCount)
		outputDirectory = if container.contains(.outputDirectory) {
			try container.decode(String.self, forKey: .outputDirectory)
		} else {
			nil
		}
	}
}

// config 의미 검증에서 반환할 JSON key path를 전달합니다.
private struct ConfigurationValidationError: Error {
	let keyPath: String
}

// targetDefaults의 허용 key를 확인하는 동적 JSON key를 정의합니다.
private struct TargetDefaultsCodingKey: CodingKey {
	static let allowedNames = ["devices", "operatingSystems", "appearances"]

	let stringValue: String
	let intValue: Int?

	init?(stringValue: String) {
		self.stringValue = stringValue
		intValue = nil
	}

	init?(intValue: Int) {
		return nil
	}
}
