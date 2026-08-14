//
//  ExecutionPlan.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation

// 실행 없이 확인할 scenario의 순서형 계획을 표현합니다.
package struct ExecutionPlan: Codable, Sendable, Equatable {
	package let scenarioID: String
	package let profile: String
	package let outputDirectoryPath: String
	package let testDataRequirements: [TestDataRequirement]
	package let targets: [ExecutionPlanTarget]

	// scenario, 출력 기준 경로, data 요구와 target 계획으로 구성합니다.
	package init(
		scenarioID: String,
		profile: String,
		outputDirectoryPath: String,
		testDataRequirements: [TestDataRequirement],
		targets: [ExecutionPlanTarget]
	) {
		self.scenarioID = scenarioID
		self.profile = profile
		self.outputDirectoryPath = outputDirectoryPath
		self.testDataRequirements = testDataRequirements
		self.targets = targets
	}
}

// 실행 계획을 막는 scenario 검증 오류를 파일 문맥과 함께 표현합니다.
package struct ExecutionPlanValidationFailure: Codable, Sendable, Equatable {
	package let errors: [ScenarioValidationError]

	// 정해진 순서의 scenario 검증 오류로 실패 값을 구성합니다.
	package init(errors: [ScenarioValidationError]) {
		self.errors = errors
	}
}

// 하나의 target에서 실행할 순서형 step과 출력 기준 경로를 표현합니다.
package struct ExecutionPlanTarget: Codable, Sendable, Equatable {
	package let target: Target
	package let outputDirectoryPath: String
	package let steps: [ExecutionPlanStep]
	package let assertions: [String]
	package let evidence: [String]

	// target별 실행과 증거 참조 계획으로 구성합니다.
	package init(
		target: Target,
		outputDirectoryPath: String,
		steps: [ExecutionPlanStep],
		assertions: [String],
		evidence: [String]
	) {
		self.target = target
		self.outputDirectoryPath = outputDirectoryPath
		self.steps = steps
		self.assertions = assertions
		self.evidence = evidence
	}
}

// 하나의 scenario step과 실행 시 예상되는 부작용을 표현합니다.
package struct ExecutionPlanStep: Codable, Sendable, Equatable {
	package let id: String
	package let action: ScenarioStepAction
	package let selector: ScenarioSelector?
	package let sideEffects: [ExecutionPlanSideEffect]

	// step 식별자, action, selector, 부작용으로 구성합니다.
	package init(
		id: String,
		action: ScenarioStepAction,
		selector: ScenarioSelector?,
		sideEffects: [ExecutionPlanSideEffect]
	) {
		self.id = id
		self.action = action
		self.selector = selector
		self.sideEffects = sideEffects
	}
}

// dry-run에서 미리 알릴 실행 부작용 종류를 정의합니다.
package enum ExecutionPlanSideEffect: String, Codable, Sendable, Equatable {
	case appLaunch
	case simulatorUse
}

// scenario와 project 설정을 실행 계획으로 정규화합니다.
package struct ExecutionPlanBuilder: Sendable {
	// 기본 생성기를 구성합니다.
	package init() {}

	// 검증된 scenario와 설정을 실행하지 않는 계획으로 변환합니다.
	package func build(
		scenario: Scenario,
		configuration: QALenzConfiguration
	) throws -> ExecutionPlan {
		let selection = try TargetSelectionDecoder().decode(scenario.matrix)
		let targets = try TargetGenerator().generate(
			selection,
			defaults: configuration.targetDefaults,
			policy: configuration.targetPolicy
		)
		let steps = scenario.steps.map(makeStep)
		let outputDirectoryURL = configuration.outputDirectoryURL.standardizedFileURL

		return .init(
			scenarioID: scenario.id,
			profile: scenario.profile,
			outputDirectoryPath: outputDirectoryURL.path,
			testDataRequirements: scenario.testDataRequirements,
			targets: targets.map { target in
				.init(
					target: target,
					outputDirectoryPath: outputDirectoryURL
						.appendingPathComponent(target.identifier, isDirectory: true)
						.path,
					steps: steps,
					assertions: scenario.assertions.map(\.afterStepID),
					evidence: scenario.evidence.map(\.afterStepID)
				)
			}
		)
	}

	// action이 요구하는 app 및 Simulator 부작용을 step으로 정규화합니다.
	private func makeStep(_ step: ScenarioStep) -> ExecutionPlanStep {
		.init(
			id: step.id,
			action: step.action,
			selector: step.selector,
			sideEffects: step.action == .buildAndRun ? [.appLaunch, .simulatorUse] : [.simulatorUse]
		)
	}
}
