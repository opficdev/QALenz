//
//  DoctorReport.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// Doctor 검사 결과와 최종 상태를 전달합니다.
package struct DoctorReport: Codable, Sendable, Equatable {
	package let diagnostics: [DoctorDiagnostic]
	package let result: RunResult

	// 검사 항목으로 최종 결과를 초기화합니다.
	package init(diagnostics: [DoctorDiagnostic]) {
		self.diagnostics = diagnostics
		result = diagnostics.contains {
			$0.requirement == .required && $0.status != .available
		} ? .failed : .passed
	}

	// 디코더에서 진단 항목과 일치하는 최종 결과를 복원합니다.
	package init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let diagnostics = try container.decode(
			[DoctorDiagnostic].self,
			forKey: .diagnostics
		)
		let decodedResult = try container.decode(RunResult.self, forKey: .result)
		let report = Self(diagnostics: diagnostics)

		guard decodedResult == report.result else {
			throw DecodingError.dataCorruptedError(
				forKey: .result,
				in: container,
				debugDescription: "The result must match the diagnostics."
			)
		}

		self = report
	}

	// 인코더에 진단 항목과 계산된 최종 결과를 기록합니다.
	package func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(diagnostics, forKey: .diagnostics)
		try container.encode(result, forKey: .result)
	}

	// 보고서의 코딩 키를 정의합니다.
	private enum CodingKeys: String, CodingKey {
		case diagnostics
		case result
	}
}
