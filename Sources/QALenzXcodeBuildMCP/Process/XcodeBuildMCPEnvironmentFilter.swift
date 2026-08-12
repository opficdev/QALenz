//
//  XcodeBuildMCPEnvironmentFilter.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

// 자식 process에 전달할 환경 변수를 허용 목록으로 제한합니다.
package struct XcodeBuildMCPEnvironmentFilter: Sendable {
	private let allowedNames: Set<String> = [
		"PATH",
		"HOME",
		"TMPDIR",
		"DEVELOPER_DIR",
		"XCODEBUILDMCP_CWD"
	]

	// 정해진 환경 변수 허용 목록으로 filter를 구성합니다.
	package init() {}

	// 허용된 이름의 환경 변수만 반환합니다.
	package func apply(
		to environment: [String: String]
	) -> [String: String] {
		environment.filter { allowedNames.contains($0.key) }
	}
}
