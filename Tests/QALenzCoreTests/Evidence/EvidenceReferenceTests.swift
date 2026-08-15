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

	// 알 수 없는 evidence kind의 decode 오류 문맥을 보존하는지 검증합니다.
	@Test
	func 알_수_없는_kind의_decode_오류_문맥을_보존한다() {
		let data = Data(
			"""
			{
			  "kind": "unknown",
			  "relativePath": "evidence/launch.png",
			  "stepID": "launch",
			  "isRedacted": true,
			  "isOriginalRetained": false
			}
			""".utf8
		)

		do {
			_ = try JSONDecoder().decode(EvidenceReference.self, from: data)
			#expect(Bool(false))
		} catch let DecodingError.dataCorrupted(context) {
			#expect(context.codingPath.last?.stringValue == "kind")
		} catch {
			#expect(Bool(false))
		}
	}

	// 상대 경로 탈출 오류를 relativePath 문맥으로 변환하는지 검증합니다.
	@Test
	func 상대_경로_탈출_decode_오류를_relativePath_문맥으로_변환한다() {
		let data = Data(
			"""
			{
			  "kind": "log",
			  "relativePath": "../secret.log",
			  "stepID": "launch",
			  "isRedacted": true,
			  "isOriginalRetained": false
			}
			""".utf8
		)

		do {
			_ = try JSONDecoder().decode(EvidenceReference.self, from: data)
			#expect(Bool(false))
		} catch let DecodingError.dataCorrupted(context) {
			#expect(context.codingPath.last?.stringValue == "relativePath")
		} catch {
			#expect(Bool(false))
		}
	}
}
