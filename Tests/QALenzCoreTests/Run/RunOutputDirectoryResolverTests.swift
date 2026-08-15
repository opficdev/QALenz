//
//  RunOutputDirectoryResolverTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// RunOutputDirectoryResolver의 override 경로 정규화와 보호를 검증합니다.
@Suite
struct RunOutputDirectoryResolverTests {
	// 상대 override를 현재 작업 경로 기준 절대 경로로 정규화하는지 검증합니다.
	@Test
	func 상대_override를_현재_작업_경로_기준_절대_경로로_정규화한다() throws {
		let url = try RunOutputDirectoryResolver(
			homeDirectoryURL: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
		).resolve(
			overridePath: "artifacts/../runs",
			relativeTo: URL(fileURLWithPath: "/tmp/Work", isDirectory: true),
			projectRootURL: URL(fileURLWithPath: "/tmp/Project", isDirectory: true)
		)

		#expect(url == URL(fileURLWithPath: "/tmp/Work/runs", isDirectory: true))
	}

	// 사용자 home, repository, repository 하위 경로를 override로 거부하는지 검증합니다.
	@Test(arguments: ["/", "/Users/tester", "/tmp/Project", "/tmp/Project/Artifacts"])
	func 보호_경로를_override로_거부한다(overridePath: String) {
		#expect(throws: RunOutputDirectoryError.self) {
			try RunOutputDirectoryResolver(
				homeDirectoryURL: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
			).resolve(
				overridePath: overridePath,
				relativeTo: URL(fileURLWithPath: "/tmp/Work", isDirectory: true),
				projectRootURL: URL(fileURLWithPath: "/tmp/Project", isDirectory: true)
			)
		}
	}

	// project를 가리키는 symbolic link 하위 override를 거부하는지 검증합니다.
	@Test
	func project를_가리키는_symbolic_link_하위_override를_거부한다() throws {
		let rootURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let projectURL = rootURL.appendingPathComponent("Project", isDirectory: true)
		let outsideURL = rootURL.appendingPathComponent("Outside", isDirectory: true)
		let linkURL = outsideURL.appendingPathComponent("project-link", isDirectory: false)
		defer { try? FileManager.default.removeItem(at: rootURL) }
		try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: outsideURL, withIntermediateDirectories: true)
		try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: projectURL)

		#expect(throws: RunOutputDirectoryError.self) {
			try RunOutputDirectoryResolver(
				homeDirectoryURL: rootURL.appendingPathComponent("Home", isDirectory: true)
			).resolve(
				overridePath: "project-link/Artifacts",
				relativeTo: outsideURL,
				projectRootURL: projectURL
			)
		}
	}

	// project root가 root이면 모든 output override를 거부하는지 검증합니다.
	@Test
	func project_root가_root이면_output_override를_거부한다() {
		#expect(throws: RunOutputDirectoryError.self) {
			try RunOutputDirectoryResolver(
				homeDirectoryURL: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
			).resolve(
				overridePath: "/tmp/runs",
				relativeTo: URL(fileURLWithPath: "/tmp", isDirectory: true),
				projectRootURL: URL(fileURLWithPath: "/", isDirectory: true)
			)
		}
	}
}
