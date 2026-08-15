//
//  UIStepConfiguration.swift
//  QALenz
//
//  Created by opfic on 8/16/26.
//

import Foundation

// UI step parameter를 실행 정책에 필요한 값으로 정규화합니다.
struct UIStepConfiguration {
	let timeoutMilliseconds: Int
	let retryCount: Int
	let preDelayMilliseconds: Int
	let postDelayMilliseconds: Int
	let durationMilliseconds: Int?
	let swipeDirection: UISwipeDirection?
	let distance: Double?
	let text: String?
	let replaceExisting: Bool

	// action별 parameter를 검증하고 실행 정책 값으로 구성합니다.
	init(step: ExecutionPlanStep) throws {
		let values = try Self.values(from: step)
		timeoutMilliseconds = try Self.integer("timeoutMilliseconds", in: values, default: 5_000, minimum: 0, step: step)
		retryCount = try Self.integer(
			"retryCount",
			in: values,
			default: 0,
			minimum: 0,
			maximum: 100,
			step: step
		)
		preDelayMilliseconds = try Self.integer("preDelayMilliseconds", in: values, default: 0, minimum: 0, step: step)
		postDelayMilliseconds = try Self.integer("postDelayMilliseconds", in: values, default: 0, minimum: 0, step: step)
		durationMilliseconds = try Self.optionalInteger("durationMilliseconds", in: values, minimum: 1, step: step)
		distance = try Self.distance(in: values, step: step)
		text = try Self.text(in: values, step: step)
		replaceExisting = try Self.boolean("replaceExisting", in: values, default: false, step: step)
		swipeDirection = try Self.direction(in: values, step: step)

		try Self.validateAction(step.action, values: values, configuration: self, step: step)
	}

	// parameter object를 읽고 object 이외의 값은 거부합니다.
	private static func values(from step: ExecutionPlanStep) throws -> [String: ExecutionPlanParameter] {
		guard let parameters = step.parameters else { return [:] }
		guard case let .object(values) = parameters else {
			throw failure(step: step, keyPath: "parameters")
		}

		return values
	}

	// 정수 parameter를 기본값, 하한과 함께 읽습니다.
	private static func integer(
		_ key: String,
		in values: [String: ExecutionPlanParameter],
		default defaultValue: Int,
		minimum: Int,
		maximum: Int? = nil,
		step: ExecutionPlanStep
	) throws -> Int {
		guard let value = values[key] else { return defaultValue }
		guard case let .number(rawValue) = value,
			let integer = Int(rawValue),
			minimum <= integer,
			maximum.map({ integer <= $0 }) ?? true else {
			throw failure(step: step, keyPath: "parameters.\(key)")
		}

		return integer
	}

	// 선택 정수 parameter를 읽습니다.
	private static func optionalInteger(
		_ key: String,
		in values: [String: ExecutionPlanParameter],
		minimum: Int,
		step: ExecutionPlanStep
	) throws -> Int? {
		guard values[key] != nil else { return nil }

		return try integer(key, in: values, default: minimum, minimum: minimum, step: step)
	}

	// boolean parameter를 기본값과 함께 읽습니다.
	private static func boolean(
		_ key: String,
		in values: [String: ExecutionPlanParameter],
		default defaultValue: Bool,
		step: ExecutionPlanStep
	) throws -> Bool {
		guard let value = values[key] else { return defaultValue }
		guard case let .boolean(boolean) = value else {
			throw failure(step: step, keyPath: "parameters.\(key)")
		}

		return boolean
	}

	// swipe direction parameter를 UI automation 공통 값으로 변환합니다.
	private static func direction(
		in values: [String: ExecutionPlanParameter],
		step: ExecutionPlanStep
	) throws -> UISwipeDirection? {
		guard let value = values["direction"] else { return nil }
		guard case let .string(direction) = value else {
			throw failure(step: step, keyPath: "parameters.direction")
		}

		switch direction {
		case "up": return .upward
		case "down": return .downward
		case "left": return .leftward
		case "right": return .rightward
		default: throw failure(step: step, keyPath: "parameters.direction")
		}
	}

	// swipe distance parameter를 허용 범위 안의 소수로 읽습니다.
	private static func distance(
		in values: [String: ExecutionPlanParameter],
		step: ExecutionPlanStep
	) throws -> Double? {
		guard let value = values["distance"] else { return nil }
		guard case let .number(rawValue) = value,
			let distance = Double(rawValue),
			0 < distance,
			distance <= 1 else {
			throw failure(step: step, keyPath: "parameters.distance")
		}

		return distance
	}

	// typeText action의 text parameter를 읽습니다.
	private static func text(
		in values: [String: ExecutionPlanParameter],
		step: ExecutionPlanStep
	) throws -> String? {
		guard let value = values["text"] else { return nil }
		guard case let .string(text) = value, !text.isEmpty else {
			throw failure(step: step, keyPath: "parameters.text")
		}

		return text
	}

	// action이 허용하는 parameter와 필수 parameter를 검증합니다.
	private static func validateAction(
		_ action: ScenarioStepAction,
		values: [String: ExecutionPlanParameter],
		configuration: UIStepConfiguration,
		step: ExecutionPlanStep
	) throws {
		let commonKeys: Set<String> = [
			"timeoutMilliseconds",
			"retryCount",
			"preDelayMilliseconds",
			"postDelayMilliseconds"
		]
		let actionKeys: Set<String>

		switch action {
		case .longPress:
			actionKeys = ["durationMilliseconds"]
		case .swipe:
			actionKeys = ["durationMilliseconds", "direction", "distance"]
			guard configuration.swipeDirection != nil else {
				throw failure(step: step, keyPath: "parameters.direction")
			}
		case .typeText:
			actionKeys = ["text", "replaceExisting"]
			guard configuration.text != nil else {
				throw failure(step: step, keyPath: "parameters.text")
			}
		case .buildAndRun, .waitForUI, .snapshotUI, .tap, .screenshot, .recordVideo:
			actionKeys = []
		}

		guard Set(values.keys).isSubset(of: commonKeys.union(actionKeys)) else {
			throw failure(step: step, keyPath: "parameters")
		}
	}

	// 실행하지 않은 parameter 오류를 step 문맥과 함께 구성합니다.
	private static func failure(step: ExecutionPlanStep, keyPath: String) -> RunError {
		.init(
			kind: .configuration,
			code: .init(rawValue: "execution.ui.step.parameters.invalid"),
			context: .init(step: step.id, keyPath: keyPath)
		)
	}
}
