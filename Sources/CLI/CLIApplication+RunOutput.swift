//
//  CLIApplication+RunOutput.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import QALenzCore

// 단일 target run 결과를 CLI 출력으로 변환합니다.
extension CLIApplication {
	// 저장한 단일 target run 결과를 요청한 출력 형식의 프로세스 결과로 변환합니다.
	package static func result(
		for execution: SingleTargetRunExecution,
		format: CLIOutputFormat
	) -> CLIProcessResult {
		switch format {
		case .text:
			return .init(
				standardOutput: "[\(execution.manifest.result.status.rawValue)] \(execution.manifestURL.path)",
				standardError: nil,
				exitStatus: .init(result: execution.manifest.result)
			)
		case .json:
			return jsonResult(for: execution.manifest)
		}
	}

	// RunManifest를 정렬된 JSON 프로세스 결과로 변환합니다.
	private static func jsonResult(for manifest: RunManifest) -> CLIProcessResult {
		do {
			let data = try RunManifestCodec().encode(manifest)
			guard let output = String(data: data, encoding: .utf8) else {
				throw RunManifestStoreError.storageFailed
			}

			return .init(
				standardOutput: output,
				standardError: nil,
				exitStatus: .init(result: manifest.result)
			)
		} catch {
			return .init(
				standardOutput: nil,
				standardError: "Run manifest encoding failed.",
				exitStatus: .executionError
			)
		}
	}
}
