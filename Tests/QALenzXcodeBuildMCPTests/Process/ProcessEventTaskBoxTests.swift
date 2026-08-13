//
//  ProcessEventTaskBoxTests.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Testing
@testable import QALenzXcodeBuildMCP

// ProcessEventTaskBox의 Task 취소 처리를 검증합니다.
@Suite
struct ProcessEventTaskBoxTests {
	// Task 저장 전 취소 요청이 들어와도 이후 Task를 중단하는지 검증합니다.
	@Test
	func Task_저장_전_취소_요청이_이후_Task를_중단한다() async {
		let taskBox = ProcessEventTaskBox()
		taskBox.cancel()
		let task = Task {
			try? await Task.sleep(for: .milliseconds(10))
			guard !Task.isCancelled else { return }
			Issue.record("저장 전 취소 요청이 Task에 전달되지 않음")
		}

		taskBox.store(task)
		await task.value
		taskBox.finish()
	}
}
