//
//  EvidenceReference.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// 저장한 증거 파일의 종류를 정의합니다.
package enum EvidenceKind: String, Codable, Sendable, Equatable {
	case screenshot
	case uiHierarchy
	case log
	case video
}

// run 디렉터리 기준 증거 파일 위치와 민감정보 metadata를 표현합니다.
package struct EvidenceReference: Codable, Sendable, Equatable {
	package let kind: EvidenceKind
	package let relativePath: String
	package let stepID: String
	package let isRedacted: Bool
	package let isOriginalRetained: Bool

	// 증거 파일의 상대 경로와 redaction metadata로 초기화합니다.
	package init(
		kind: EvidenceKind,
		relativePath: String,
		stepID: String,
		isRedacted: Bool,
		isOriginalRetained: Bool
	) throws {
		guard Self.isValidRelativePath(relativePath) else {
			throw EvidenceReferenceError.relativePathInvalid
		}

		self.kind = kind
		self.relativePath = relativePath
		self.stepID = stepID
		self.isRedacted = isRedacted
		self.isOriginalRetained = isOriginalRetained
	}

	// JSON 값을 경로 검증을 거쳐 증거 참조로 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let kind = try container.decode(EvidenceKind.self, forKey: .kind)
		let relativePath = try container.decode(String.self, forKey: .relativePath)
		let stepID = try container.decode(String.self, forKey: .stepID)
		let isRedacted = try container.decode(Bool.self, forKey: .isRedacted)
		let isOriginalRetained = try container.decode(Bool.self, forKey: .isOriginalRetained)

		do {
			try self.init(
				kind: kind,
				relativePath: relativePath,
				stepID: stepID,
				isRedacted: isRedacted,
				isOriginalRetained: isOriginalRetained
			)
		} catch EvidenceReferenceError.relativePathInvalid {
			throw DecodingError.dataCorruptedError(
				forKey: .relativePath,
				in: container,
				debugDescription: "Evidence paths must be nonempty run-relative paths."
			)
		}
	}

	// 증거 참조를 JSON에 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(kind, forKey: .kind)
		try container.encode(relativePath, forKey: .relativePath)
		try container.encode(stepID, forKey: .stepID)
		try container.encode(isRedacted, forKey: .isRedacted)
		try container.encode(isOriginalRetained, forKey: .isOriginalRetained)
	}

	// 증거 파일이 run 디렉터리 안에 남는 상대 경로인지 반환합니다.
	private static func isValidRelativePath(_ path: String) -> Bool {
		guard !path.isEmpty, !path.hasPrefix("/") else { return false }

		return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
	}

	// JSON coding key를 정의합니다.
	private enum CodingKeys: String, CodingKey {
		case kind
		case relativePath
		case stepID
		case isRedacted
		case isOriginalRetained
	}
}

// 증거 참조의 경로 검증 오류를 정의합니다.
package enum EvidenceReferenceError: Error, Sendable, Equatable {
	case relativePathInvalid
}
