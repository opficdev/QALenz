//
//  QALenzConfiguration.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// 프로젝트별 QALenz 실행 설정의 정규화된 값을 전달합니다.
package struct QALenzConfiguration: Sendable, Equatable {
	package static let supportedSchemaVersion = 1

	package let schemaVersion: Int
	package let projectRootURL: URL
	package let xcodeBuildMCPProfile: String
	package let scenariosDirectoryURL: URL
	package let outputDirectoryURL: URL
	package let targetDefaults: TargetDefaults
	package let targetPolicy: TargetPolicy

	// 검증과 경로 정규화를 마친 설정 값으로 초기화합니다.
	package init(
		schemaVersion: Int,
		projectRootURL: URL,
		xcodeBuildMCPProfile: String,
		scenariosDirectoryURL: URL,
		outputDirectoryURL: URL,
		targetDefaults: TargetDefaults,
		targetPolicy: TargetPolicy
	) {
		self.schemaVersion = schemaVersion
		self.projectRootURL = projectRootURL
		self.xcodeBuildMCPProfile = xcodeBuildMCPProfile
		self.scenariosDirectoryURL = scenariosDirectoryURL
		self.outputDirectoryURL = outputDirectoryURL
		self.targetDefaults = targetDefaults
		self.targetPolicy = targetPolicy
	}
}
