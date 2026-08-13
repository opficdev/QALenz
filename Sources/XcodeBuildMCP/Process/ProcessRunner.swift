//
//  ProcessRunner.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// 외부 process 실행을 주입 가능한 경계로 추상화합니다.
package protocol ProcessRunning: Sendable {
	// 요청한 process를 실행하고 표준 출력 및 종료 상태를 반환합니다.
	func run(_ request: ProcessRequest) async throws -> ProcessResult
}
