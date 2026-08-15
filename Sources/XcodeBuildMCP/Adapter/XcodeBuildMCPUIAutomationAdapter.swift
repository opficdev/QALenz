//
//  XcodeBuildMCPUIAutomationAdapter.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import QALenzCore

// XcodeBuildMCP 구조화 응답을 UI automation 공통 계약으로 변환합니다.
package struct XcodeBuildMCPUIAutomationAdapter: UIAutomationExecuting, Sendable {
	private let adapter: any XcodeBuildMCPAdapter

	// 일반 XcodeBuildMCP adapter로 UI automation 변환기를 구성합니다.
	package init(adapter: any XcodeBuildMCPAdapter) {
		self.adapter = adapter
	}

	// 현재 화면의 runtime snapshot 식별 정보를 반환합니다.
	package func snapshotUI(
		profile: String,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationSnapshot, RunError> {
		let result = await adapter.execute(.init(
			operation: .snapshotUI,
			arguments: [.init(name: "profile", value: profile)],
			timeout: .milliseconds(timeoutMilliseconds)
		))

		return payload(from: result).flatMap(snapshot)
	}

	// selector가 가리키는 단일 element 참조와 현재 snapshot을 반환합니다.
	package func waitForUI(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationWaitResult, RunError> {
		let result = await adapter.execute(.init(
			operation: .waitForUI,
			arguments: waitArguments(
				profile: profile,
				selector: selector,
				timeoutMilliseconds: timeoutMilliseconds
			),
			timeout: waitProcessTimeout(timeoutMilliseconds)
		))

		return payload(from: result).flatMap(waitResult)
	}

	// 현재 element 참조를 tap하고 후속 snapshot 정보를 반환합니다.
	package func tap(
		profile: String,
		elementReference: UIElementReference,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		let result = await adapter.execute(.init(
			operation: .tapUI,
			arguments: [
				.init(name: "profile", value: profile),
				.init(name: "element.reference", value: elementReference.rawValue)
			],
			timeout: .milliseconds(timeoutMilliseconds)
		))

		return payload(from: result).flatMap(actionResult)
	}

	// 현재 element 참조를 지정한 시간만큼 누르고 후속 snapshot 정보를 반환합니다.
	package func longPress(
		profile: String,
		elementReference: UIElementReference,
		durationMilliseconds: Int?,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		var arguments = [
			XcodeBuildMCPArgument(name: "profile", value: profile),
			.init(name: "element.reference", value: elementReference.rawValue)
		]
		if let durationMilliseconds {
			arguments.append(.init(
				name: "duration.seconds",
				value: String(Double(durationMilliseconds) / 1_000)
			))
		}

		let result = await adapter.execute(.init(
			operation: .longPressUI,
			arguments: arguments,
			timeout: .milliseconds(timeoutMilliseconds)
		))

		return payload(from: result).flatMap(actionResult)
	}

	// 현재 element 범위에서 swipe하고 후속 snapshot 정보를 반환합니다.
	package func swipe(
		profile: String,
		elementReference: UIElementReference,
		request: UIAutomationSwipeRequest
	) async -> Result<UIAutomationActionResult, RunError> {
		var arguments = [
			XcodeBuildMCPArgument(name: "profile", value: profile),
			.init(name: "element.reference", value: elementReference.rawValue),
			.init(name: "direction", value: request.direction.argumentValue)
		]
		if let durationMilliseconds = request.durationMilliseconds {
			arguments.append(.init(
				name: "duration.seconds",
				value: String(Double(durationMilliseconds) / 1_000)
			))
		}
		if let distance = request.distance {
			arguments.append(.init(name: "distance", value: String(distance)))
		}

		let result = await adapter.execute(.init(
			operation: .swipeUI,
			arguments: arguments,
			timeout: .milliseconds(request.timeoutMilliseconds)
		))

		return payload(from: result).flatMap(actionResult)
	}

	// 현재 element 참조에 text를 입력하고 후속 snapshot 정보를 반환합니다.
	package func typeText(
		profile: String,
		elementReference: UIElementReference,
		text: String,
		replaceExisting: Bool,
		timeoutMilliseconds: Int
	) async -> Result<UIAutomationActionResult, RunError> {
		let result = await adapter.execute(.init(
			operation: .typeTextUI,
			arguments: [
				.init(name: "profile", value: profile),
				.init(name: "element.reference", value: elementReference.rawValue),
				.init(name: "text", value: text),
				.init(name: "replace.existing", value: String(replaceExisting))
			],
			timeout: .milliseconds(timeoutMilliseconds)
		))

		return payload(from: result).flatMap(actionResult)
	}

	// UI operation 결과에서 검증된 payload 또는 snapshot을 보존한 오류를 반환합니다.
	private func payload(from result: XcodeBuildMCPResult) -> Result<XcodeBuildMCPPayload, RunError> {
		switch result.result {
		case .passed:
			guard let payload = result.payload else {
				return .failure(failure(code: "adapter.xcodebuildmcp.ui.output.invalid"))
			}

			return .success(payload)
		case .failed:
			return .failure(failure(code: "adapter.xcodebuildmcp.command.failed"))
		case let .errored(error):
			return .failure(contextual(error, payload: result.payload))
		}
	}

	// wait-for-ui 요청에 profile, selector 및 시간 제한 argument를 구성합니다.
	private func waitArguments(
		profile: String,
		selector: ScenarioSelector,
		timeoutMilliseconds: Int
	) -> [XcodeBuildMCPArgument] {
		var arguments = [
			XcodeBuildMCPArgument(name: "profile", value: profile),
			.init(name: "predicate", value: "exists"),
			.init(name: "timeout.milliseconds", value: String(timeoutMilliseconds))
		]
		if let identifier = selector.identifier {
			arguments.append(.init(name: "selector.identifier", value: identifier))
		}
		if let label = selector.label {
			arguments.append(.init(name: "selector.label", value: label))
		}
		if let role = selector.role {
			arguments.append(.init(name: "selector.role", value: role))
		}
		if let value = selector.value {
			arguments.append(.init(name: "selector.value", value: value))
		}

		return arguments
	}

	// 도구의 selector 대기 결과를 수집할 수 있도록 process 시간 제한에 유예 시간을 더합니다.
	private func waitProcessTimeout(_ timeoutMilliseconds: Int) -> Duration {
		.milliseconds(timeoutMilliseconds) + .seconds(1)
	}

	// capture payload에서 현재 runtime snapshot 식별 정보를 추출합니다.
	private func snapshot(_ payload: XcodeBuildMCPPayload) -> Result<UIAutomationSnapshot, RunError> {
		guard let capture = payload.objectValue(for: "capture"),
			let snapshot = snapshot(from: capture) else {
			return .failure(failure(code: "adapter.xcodebuildmcp.ui.output.invalid"))
		}

		return .success(snapshot)
	}

	// wait-for-ui payload에서 존재 여부와 단일 element 참조를 추출합니다.
	private func waitResult(_ payload: XcodeBuildMCPPayload) -> Result<UIAutomationWaitResult, RunError> {
		guard let capture = payload.objectValue(for: "capture"),
			let snapshot = snapshot(from: capture),
			let waitMatch = payload.objectValue(for: "waitMatch"),
			let matches = waitMatch.arrayValue(for: "matches"),
			!matches.isEmpty else {
			return .failure(failure(code: "adapter.xcodebuildmcp.ui.output.invalid"))
		}

		return .success(.init(
			snapshot: snapshot,
			elementReference: matches.count == 1
				? matches[0].stringValue(for: "ref").map(UIElementReference.init(rawValue:))
				: nil
		))
	}

	// UI action payload에서 선택적인 후속 snapshot 정보를 추출합니다.
	private func actionResult(_ payload: XcodeBuildMCPPayload) -> Result<UIAutomationActionResult, RunError> {
		guard let capture = payload.objectValue(for: "capture") else {
			return .success(.init())
		}
		guard let snapshot = snapshot(from: capture) else {
			return .failure(failure(code: "adapter.xcodebuildmcp.ui.output.invalid"))
		}

		return .success(.init(snapshot: snapshot))
	}

	// capture object가 runtime snapshot 식별 정보를 포함하는지 검증합니다.
	private func snapshot(from capture: XcodeBuildMCPPayload) -> UIAutomationSnapshot? {
		guard capture.stringValue(for: "type") == "runtime-snapshot",
			let screenHash = capture.stringValue(for: "screenHash"),
			let sequence = capture.integerValue(for: "seq") else {
			return nil
		}

		return .init(screenHash: screenHash, sequence: sequence)
	}

	// UI 응답 변환 실패를 원본 응답 없이 정규화합니다.
	private func failure(code: String) -> RunError {
		.init(
			kind: .adapter,
			code: .init(rawValue: code),
			context: .init(command: "ui-automation")
		)
	}

	// UI 오류 payload의 코드와 snapshot을 정규화된 오류 문맥에 보존합니다.
	private func contextual(_ error: RunError, payload: XcodeBuildMCPPayload?) -> RunError {
		let code = payload?
			.objectValue(for: "uiError")?
			.stringValue(for: "code")
		let snapshot = payload?
			.objectValue(for: "capture")
			.flatMap(snapshot)

		return .init(
			kind: error.kind,
			code: .init(rawValue: code.map { "adapter.xcodebuildmcp.ui.\($0)" } ?? error.code.rawValue),
			context: .init(
				command: error.context.command,
				target: error.context.target,
				step: error.context.step,
				assertion: error.context.assertion,
				filePath: error.context.filePath,
				keyPath: error.context.keyPath,
				uiSnapshot: snapshot ?? error.context.uiSnapshot
			)
		)
	}
}

// UI swipe 방향을 XcodeBuildMCP argument 값으로 변환합니다.
private extension UISwipeDirection {
	var argumentValue: String {
		switch self {
		case .upward:
			"up"
		case .downward:
			"down"
		case .leftward:
			"left"
		case .rightward:
			"right"
		}
	}
}

// 검증된 XcodeBuildMCP payload의 object 내부 값을 읽습니다.
private extension XcodeBuildMCPPayload {
	func objectValue(for key: String) -> XcodeBuildMCPPayload? {
		guard case let .object(values) = self else { return nil }

		return values[key]
	}

	func arrayValue(for key: String) -> [XcodeBuildMCPPayload]? {
		guard let value = objectValue(for: key), case let .array(values) = value else {
			return nil
		}

		return values
	}

	func stringValue(for key: String) -> String? {
		guard let value = objectValue(for: key), case let .string(string) = value else {
			return nil
		}

		return string
	}

	func integerValue(for key: String) -> Int? {
		guard let value = objectValue(for: key) else { return nil }

		switch value {
		case let .integer(integer):
			return Int(exactly: integer)
		case let .unsignedInteger(integer):
			return Int(exactly: integer)
		default:
			return nil
		}
	}
}
