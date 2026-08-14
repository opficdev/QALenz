//
//  DiscoveryResult.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// 조회한 실행 대상 후보를 정규화된 순서로 보관합니다.
package struct DiscoveryResult: Sendable, Equatable {
	package let projects: [DiscoveryProject]
	package let workspaces: [DiscoveryWorkspace]
	package let schemes: [DiscoveryScheme]
	package let simulators: [DiscoverySimulator]

	// 경로와 이름 및 Simulator 후보를 profile 입력에 사용할 값으로 구성합니다.
	package init(
		projectURLs: [URL],
		workspaceURLs: [URL],
		schemeNames: [String],
		simulators: [DiscoverySimulator],
		relativeTo rootURL: URL
	) {
		projects = Self.normalizedPaths(from: projectURLs, relativeTo: rootURL)
			.map(DiscoveryProject.init(path:))
		workspaces = Self.normalizedPaths(from: workspaceURLs, relativeTo: rootURL)
			.map(DiscoveryWorkspace.init(path:))
		schemes = Array(Set(schemeNames))
			.sorted()
			.map(DiscoveryScheme.init(name:))
		self.simulators = Self.normalizedSimulators(simulators)
	}

	// 경로 후보를 기준 경로 상대의 중복 없는 정렬된 값으로 반환합니다.
	private static func normalizedPaths(from urls: [URL], relativeTo rootURL: URL) -> [String] {
		Array(Set(urls.map { relativePath(for: $0, relativeTo: rootURL) })).sorted()
	}

	// 후보 경로를 기준 경로 기준의 상대 경로로 반환합니다.
	private static func relativePath(for url: URL, relativeTo rootURL: URL) -> String {
		let rootComponents = rootURL.standardizedFileURL.pathComponents
		let candidateComponents = url.standardizedFileURL.pathComponents
		let sharedComponentCount = zip(rootComponents, candidateComponents)
			.prefix(while: { $0 == $1 })
			.count
		let parentComponents = Array(
			repeating: "..",
			count: rootComponents.count - sharedComponentCount
		)
		let childComponents = Array(candidateComponents.dropFirst(sharedComponentCount))
		let components = parentComponents + childComponents

		return components.isEmpty ? "." : components.joined(separator: "/")
	}

	// Simulator 후보를 식별자로 중복 제거하고 이름과 식별자로 정렬합니다.
	private static func normalizedSimulators(
		_ simulators: [DiscoverySimulator]
	) -> [DiscoverySimulator] {
		let simulatorsById = simulators.reduce(into: [String: DiscoverySimulator]()) {
			if $0[$1.simulatorId] == nil {
				$0[$1.simulatorId] = $1
			}
		}

		return simulatorsById.values.sorted {
			guard $0.name == $1.name else { return $0.name < $1.name }

			return $0.simulatorId < $1.simulatorId
		}
	}
}

// 조회한 project 후보의 상대 경로를 표현합니다.
package struct DiscoveryProject: Sendable, Equatable {
	package let path: String

	// 정규화된 project 상대 경로로 후보를 구성합니다.
	package init(path: String) {
		self.path = path
	}
}

// 조회한 workspace 후보의 상대 경로를 표현합니다.
package struct DiscoveryWorkspace: Sendable, Equatable {
	package let path: String

	// 정규화된 workspace 상대 경로로 후보를 구성합니다.
	package init(path: String) {
		self.path = path
	}
}

// 조회한 scheme 후보의 이름을 표현합니다.
package struct DiscoveryScheme: Sendable, Equatable {
	package let name: String

	// 중복이 제거된 scheme 이름으로 후보를 구성합니다.
	package init(name: String) {
		self.name = name
	}
}

// 조회한 Simulator 후보의 profile 입력값을 표현합니다.
package struct DiscoverySimulator: Sendable, Equatable {
	package let name: String
	package let simulatorId: String
	package let state: String
	package let runtime: String
	package let isAvailable: Bool

	// 검증된 Simulator 속성으로 후보를 구성합니다.
	package init(
		name: String,
		simulatorId: String,
		state: String,
		runtime: String,
		isAvailable: Bool
	) {
		self.name = name
		self.simulatorId = simulatorId
		self.state = state
		self.runtime = runtime
		self.isAvailable = isAvailable
	}
}
