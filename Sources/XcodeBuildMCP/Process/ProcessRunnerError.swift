//
//  ProcessRunnerError.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// process 실행 경계에서 정규화할 수 있는 오류를 구분합니다.
package enum ProcessRunnerError: Error, Sendable, Equatable {
	case timedOut
	case executableUnavailable
	case invalidWorkingDirectory
	case failedToLaunch
}
