// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "QALenz",
	products: [
		.library(name: "QALenzCore", targets: ["QALenzCore"]),
		.executable(name: "QALenzCLI", targets: ["QALenzCLI"]),
	],
	dependencies: [],
	targets: [
		.target(name: "QALenzCore"),
		.executableTarget(
			name: "QALenzCLI",
			dependencies: ["QALenzCore"]
		),
		.testTarget(
			name: "QALenzCoreTests",
			dependencies: ["QALenzCore"]
		),
	]
)
