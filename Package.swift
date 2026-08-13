// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "QALenz",
	platforms: [
		.macOS(.v14),
	],
	products: [
		.library(name: "QALenzCore", targets: ["QALenzCore"]),
		.executable(name: "qalenz", targets: ["QALenzCLIExecutable"]),
	],
	dependencies: [
		.package(
			url: "https://github.com/apple/swift-argument-parser",
			from: "1.8.2"
		),
	],
	targets: [
		.target(
			name: "QALenzCore",
			path: "Sources/Core"
		),
		.target(
			name: "QALenzCLI",
			dependencies: [
				"QALenzCore",
				.product(
					name: "ArgumentParser",
					package: "swift-argument-parser"
				),
			],
			path: "Sources/CLI"
		),
		.executableTarget(
			name: "QALenzCLIExecutable",
			dependencies: ["QALenzCLI"],
			path: "Sources/CLIExecutable"
		),
		.testTarget(
			name: "QALenzCoreTests",
			dependencies: ["QALenzCore"]
		),
		.testTarget(
			name: "QALenzCLITests",
			dependencies: ["QALenzCLI", "QALenzCore"]
		),
	]
)
