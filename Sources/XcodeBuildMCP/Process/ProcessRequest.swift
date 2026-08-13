//
//  ProcessRequest.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// process 실행에 필요한 경로와 환경 및 시간 제한을 보관합니다.
package struct ProcessRequest: Sendable {
	package let executableURL: URL
	package let arguments: [String]
	package let workingDirectoryURL: URL
	package let environment: [String: String]
	package let timeout: Duration

	// 실행 파일과 argument 및 실행 환경으로 요청을 구성합니다.
	package init(
		executableURL: URL,
		arguments: [String],
		workingDirectoryURL: URL,
		environment: [String: String],
		timeout: Duration
	) {
		self.executableURL = executableURL
		self.arguments = arguments
		self.workingDirectoryURL = workingDirectoryURL
		self.environment = environment
		self.timeout = timeout
	}
}
