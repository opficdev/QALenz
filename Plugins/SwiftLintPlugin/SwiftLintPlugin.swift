import Foundation
import PackagePlugin

// Homebrew SwiftLint를 SwiftPM 빌드 작업으로 연결
@main
struct SwiftLintPlugin: BuildToolPlugin {
	// Xcode가 수집할 수 있는 빌드 작업을 구성
	func createBuildCommands(
		context: PluginContext,
		target _: Target
	) async throws -> [Command] {
		let script = context.package.directoryURL.appendingPathComponent("Scripts/lint.sh")
		let githubActions = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] ?? ""

		return [
			.prebuildCommand(
				displayName: "SwiftLint",
				executable: URL(filePath: "/bin/bash"),
				arguments: [script.path()],
				environment: [
					"PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
					"SWIFTLINT_STRICT": "false",
					"GITHUB_ACTIONS": githubActions,
				],
				outputFilesDirectory: context.pluginWorkDirectoryURL
			),
		]
	}
}
