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

	// 요청한 process의 표준 출력 조각과 종료 상태를 순서대로 반환합니다.
	func events(for request: ProcessRequest) -> AsyncThrowingStream<ProcessEvent, any Error>
}

extension ProcessRunning {
	// 분할 출력을 지원하지 않는 실행 결과를 단일 출력 사건으로 변환합니다.
	package func events(for request: ProcessRequest) -> AsyncThrowingStream<ProcessEvent, any Error> {
		.init { continuation in
			let task = Task {
				do {
					let result = try await run(request)
					continuation.yield(.standardOutput(result.standardOutput))
					continuation.yield(.terminated(result.terminationStatus))
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}

			continuation.onTermination = { @Sendable _ in
				task.cancel()
			}
		}
	}
}
