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

	// manifest 시험값을 반환합니다.
	private func manifest() throws -> RunManifest {
		.init(
			id: UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061600")!,
			createdAt: Date(timeIntervalSince1970: 1_723_718_123.123_456),
			qalenzVersion: "0.1.0",
			scenario: .init(id: "todo-completion", profile: "default"),
			result: .failed,
			targets: [.init(
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
}
