//
//  DiscoveryResultTests.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation
import Testing
@testable import QALenzCore

// DiscoveryResult의 후보 정규화 계약을 검증합니다.
@Suite
struct DiscoveryResultTests {
	// project와 workspace 후보가 상대 경로 정규화와 중복 제거 및 정렬을 거치는지 검증합니다.
	@Test
	func 경로_후보를_상대_경로로_정규화하고_타입별로_정렬한다() {
		let rootURL = URL(fileURLWithPath: "/tmp/Fixture", isDirectory: true)
		let result = DiscoveryResult(
			projectURLs: [
				rootURL.appendingPathComponent("Zeta.xcodeproj"),
				rootURL.appendingPathComponent("Projects/../Alpha.xcodeproj"),
				rootURL.appendingPathComponent("Alpha.xcodeproj"),
				URL(fileURLWithPath: "/tmp/Outside.xcodeproj")
			],
			workspaceURLs: [
				rootURL.appendingPathComponent("Workspace.xcworkspace"),
				rootURL.appendingPathComponent("Groups/../Workspace.xcworkspace")
			],
			schemeNames: ["Beta", "Alpha", "Beta"],
			simulators: [],
			relativeTo: rootURL
		)

		#expect(result.projects == [
			.init(path: "../Outside.xcodeproj"),
			.init(path: "Alpha.xcodeproj"),
			.init(path: "Zeta.xcodeproj")
		])
		#expect(result.workspaces == [.init(path: "Workspace.xcworkspace")])
		#expect(result.schemes == [.init(name: "Alpha"), .init(name: "Beta")])
	}

	// simulator 후보가 식별자로 중복 제거되고 이름과 식별자로 정렬되는지 검증합니다.
	@Test
	func simulator_후보를_식별자로_중복_제거하고_안정적으로_정렬한다() {
		let result = DiscoveryResult(
			projectURLs: [],
			workspaceURLs: [],
			schemeNames: [],
			simulators: simulatorCandidates(),
			relativeTo: URL(fileURLWithPath: "/tmp/Fixture", isDirectory: true)
		)

		#expect(result.simulators == expectedSimulators())
	}

	// 중복 제거와 정렬 전의 Simulator 후보를 반환합니다.
	private func simulatorCandidates() -> [DiscoverySimulator] {
		[
			.init(
				name: "Zeta Phone",
				simulatorId: "zeta-id",
				state: "Shutdown",
				runtime: "iOS 26.0",
				isAvailable: true
			),
			.init(
				name: "Alpha Phone",
				simulatorId: "alpha-second-id",
				state: "Shutdown",
				runtime: "iOS 25.0",
				isAvailable: false
			),
			.init(
				name: "Alpha Phone",
				simulatorId: "alpha-id",
				state: "Booted",
				runtime: "iOS 26.0",
				isAvailable: true
			),
			.init(
				name: "다른 이름",
				simulatorId: "alpha-id",
				state: "Shutdown",
				runtime: "iOS 25.0",
				isAvailable: false
			)
		]
	}

	// 정규화 뒤 기대하는 Simulator 후보를 반환합니다.
	private func expectedSimulators() -> [DiscoverySimulator] {
		[
			.init(
				name: "Alpha Phone",
				simulatorId: "alpha-id",
				state: "Booted",
				runtime: "iOS 26.0",
				isAvailable: true
			),
			.init(
				name: "Alpha Phone",
				simulatorId: "alpha-second-id",
				state: "Shutdown",
				runtime: "iOS 25.0",
				isAvailable: false
			),
			.init(
				name: "Zeta Phone",
				simulatorId: "zeta-id",
				state: "Shutdown",
				runtime: "iOS 26.0",
				isAvailable: true
			)
		]
	}
}
