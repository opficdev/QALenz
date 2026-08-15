//
//  RunManifestTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// RunManifest의 JSON 계약을 검증합니다.
@Suite
struct RunManifestTests {
	// manifest의 실행 식별자, 결과, target별 step 결과를 JSON 왕복으로 보존하는지 검증합니다.
	@Test
	func 실행_식별자와_target별_step_결과를_JSON_왕복으로_보존한다() throws {
		let manifest = try manifest()
		let data = try RunManifestCodec().encode(manifest)

		#expect(try RunManifestCodec().decode(data) == manifest)
	}

	// failed target을 포함한 passed manifest를 거부하는지 검증합니다.
	@Test
	func failed_target을_포함한_passed_manifest를_거부한다() {
		#expect(throws: RunManifestValidationError.self) {
			try manifestWithPassedResultAndFailedTarget()
		}
	}

	// failed step을 포함한 passed target을 거부하는지 검증합니다.
	@Test
	func failed_step을_포함한_passed_target을_거부한다() {
		#expect(throws: RunManifestValidationError.self) {
			try targetWithPassedResultAndFailedStep()
		}
	}

	// JSON의 상위 passed 결과가 하위 실패를 가리지 못하는지 검증합니다.
	@Test
	func JSON의_passed_manifest가_failed_target을_가리지_못한다() {
		let data = Data(
			"""
			{
			  "id": "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600",
			  "createdAt": 0,
			  "qalenzVersion": "0.1.0",
			  "scenario": {"id": "todo-completion", "profile": "default"},
			  "result": {"status": "passed"},
			  "targets": [{
				"target": {
				  "device": "iPhone 17",
				  "operatingSystem": "iOS 26.0",
				  "appearance": "light",
				  "identifier": "device=9:iPhone 17|operatingSystem=8:iOS 26.0|appearance=5:light"
				},
				"result": {"status": "failed"},
				"stepResults": [],
				"evidence": []
			  }]
			}
			""".utf8
		)

		#expect(throws: RunManifestValidationError.self) {
			try RunManifestCodec().decode(data)
		}
	}

	// manifest 시험값을 반환합니다.
	private func manifest() throws -> RunManifest {
		try .init(
			id: UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600")!,
			createdAt: Date(timeIntervalSince1970: 1_723_718_123.123_456),
			qalenzVersion: "0.1.0",
			scenario: .init(id: "todo-completion", profile: "default"),
			result: .failed,
			targets: [try .init(
				target: .init(
					device: "iPhone 17",
					operatingSystem: "iOS 26.0",
					appearance: "light"
				),
				result: .failed,
				stepResults: [
					.init(stepID: "launch", result: .passed),
					.init(stepID: "tap-complete", result: .failed)
				],
				evidence: [try .init(
					kind: .screenshot,
					relativePath: "evidence/launch.png",
					stepID: "launch",
					isRedacted: true,
					isOriginalRetained: false
				)]
			)]
		)
	}

	// 상위 통과 결과와 하위 실패 결과를 함께 구성합니다.
	private func manifestWithPassedResultAndFailedTarget() throws -> RunManifest {
		try .init(
			id: UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600")!,
			createdAt: Date(timeIntervalSince1970: 0),
			scenario: .init(id: "todo-completion", profile: "default"),
			result: .passed,
			targets: [try .init(
				target: .init(
					device: "iPhone 17",
					operatingSystem: "iOS 26.0",
					appearance: "light"
				),
				result: .failed,
				stepResults: [],
				evidence: []
			)]
		)
	}

	// 상위 통과 결과와 step 실패 결과를 함께 구성합니다.
	private func targetWithPassedResultAndFailedStep() throws -> RunTargetResult {
		try .init(
			target: .init(
				device: "iPhone 17",
				operatingSystem: "iOS 26.0",
				appearance: "light"
			),
			result: .passed,
			stepResults: [.init(stepID: "launch", result: .failed)],
			evidence: []
		)
	}
}
