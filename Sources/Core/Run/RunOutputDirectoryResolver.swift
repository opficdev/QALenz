//
//  RunOutputDirectoryResolver.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// run output directory override를 절대 경로로 정규화하고 보호 경로를 거부합니다.
package struct RunOutputDirectoryResolver: Sendable {
	private let homeDirectoryURL: URL

	// 사용자 home 경로로 resolver를 구성합니다.
	package init(homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
		self.homeDirectoryURL = homeDirectoryURL.standardizedFileURL
	}

	// 선택한 override를 현재 작업 경로 기준 절대 경로로 정규화합니다.
	package func resolve(
		overridePath: String?,
		relativeTo currentDirectoryURL: URL,
		projectRootURL: URL
	) throws -> URL? {
		guard let overridePath else { return nil }
		let outputDirectoryURL = makeURL(
			for: overridePath,
			relativeTo: currentDirectoryURL
		)

		guard isSafeOutputDirectory(
			outputDirectoryURL,
			projectRootURL: projectRootURL
		) else {
			throw RunOutputDirectoryError.unsafePath
		}

		return outputDirectoryURL
	}

	// 절대 또는 현재 작업 경로 기준 상대 URL을 구성합니다.
	private func makeURL(for path: String, relativeTo currentDirectoryURL: URL) -> URL {
		let url = if path.hasPrefix("/") {
			URL(fileURLWithPath: path, isDirectory: true)
		} else {
			currentDirectoryURL.appendingPathComponent(path, isDirectory: true)
		}

		return resolvingExistingAncestorURL(of: url)
	}

	// 사용자 home 전체와 repository 안의 output 위치를 거부합니다.
	private func isSafeOutputDirectory(
		_ outputDirectoryURL: URL,
		projectRootURL: URL
	) -> Bool {
		let projectRootURL = resolvingExistingAncestorURL(of: projectRootURL)
		let homeDirectoryURL = resolvingExistingAncestorURL(of: homeDirectoryURL)

		return outputDirectoryURL.path != "/"
			&& outputDirectoryURL.path != homeDirectoryURL.path
			&& !isSameOrDescendant(outputDirectoryURL, of: projectRootURL)
	}

	// child URL이 base URL과 같거나 하위인지 반환합니다.
	private func isSameOrDescendant(_ childURL: URL, of baseURL: URL) -> Bool {
		guard baseURL.path != "/" else { return true }

		return childURL.path == baseURL.path || childURL.path.hasPrefix(baseURL.path + "/")
	}

	// 존재하는 상위 경로의 symbolic link를 해석한 뒤 남은 경로를 붙입니다.
	private func resolvingExistingAncestorURL(of url: URL) -> URL {
		var ancestorURL = url.standardizedFileURL
		var remainingPathComponents = [String]()

		while ancestorURL.path != "/"
			&& !FileManager.default.fileExists(atPath: ancestorURL.path) {
			remainingPathComponents.insert(ancestorURL.lastPathComponent, at: 0)
			ancestorURL.deleteLastPathComponent()
		}

		return remainingPathComponents.reduce(
			ancestorURL.resolvingSymlinksInPath().standardizedFileURL
		) { url, component in
			url.appendingPathComponent(component, isDirectory: true)
		}.standardizedFileURL
	}
}

// output directory override의 경로 보호 오류를 정의합니다.
package enum RunOutputDirectoryError: Error, Sendable, Equatable {
	case unsafePath
}
