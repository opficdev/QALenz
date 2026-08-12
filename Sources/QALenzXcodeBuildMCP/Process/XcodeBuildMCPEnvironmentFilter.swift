//
//  XcodeBuildMCPEnvironmentFilter.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

package struct XcodeBuildMCPEnvironmentFilter: Sendable {
	private let allowedNames: Set<String> = [
		"PATH",
		"HOME",
		"TMPDIR",
		"DEVELOPER_DIR",
		"XCODEBUILDMCP_CWD"
	]

	package init() {}

	package func apply(
		to environment: [String: String]
	) -> [String: String] {
		environment.filter { allowedNames.contains($0.key) }
	}
}
