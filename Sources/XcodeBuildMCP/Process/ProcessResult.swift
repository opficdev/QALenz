//
//  ProcessResult.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// process의 표준 출력과 종료 상태를 보관합니다.
package struct ProcessResult: Sendable {
	package let standardOutput: Data
	package let terminationStatus: Int32

	// 표준 출력과 종료 상태로 실행 결과를 구성합니다.
	package init(standardOutput: Data, terminationStatus: Int32) {
		self.standardOutput = standardOutput
		self.terminationStatus = terminationStatus
	}
}
