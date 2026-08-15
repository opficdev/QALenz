//
//  EvidenceReferenceTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// EvidenceReference의 JSON 계약과 경로 제약을 검증합니다.
@Suite
struct EvidenceReferenceTests {
	// 증거 참조의 종류와 redaction metadata를 JSON 왕복으로 보존하는지 검증합니다.
	@Test
	func 종류와_redaction_metadata를_JSON_왕복으로_보존한다() throws {
		let reference = try EvidenceReference(
			kind: .screenshot,
			relativePath: "evidence/launch.png",
			stepID: "launch",
			isRedacted: true,
			isOriginalRetained: false
		)
		let data = try JSONEncoder().encode(reference)

		#expect(try JSONDecoder().decode(EvidenceReference.self, from: data) == reference)
	}

	// run 디렉터리 밖을 가리키는 상대 경로와 절대 경로를 거부하는지 검증합니다.
	@Test(arguments: ["", "/tmp/evidence.png", "../evidence.png", "evidence/../../secret.txt"])
	func run_디렉터리_밖을_가리키는_경로를_거부한다(relativePath: String) {
		#expect(throws: EvidenceReferenceError.self) {
			try EvidenceReference(
				kind: .log,
				relativePath: relativePath,
				stepID: "launch",
				isRedacted: true,
				isOriginalRetained: false
			)
		}
	}
}
