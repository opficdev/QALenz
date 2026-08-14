//
//  ScenarioSchema.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

import Foundation

// QALenz scenario JSON Schema resource를 제공합니다.
package enum ScenarioSchema {
	// module bundle에 포함된 schema resource의 URL입니다.
	package static let resourceURL = Bundle.module.url(
		forResource: "qalenz-scenario.schema",
		withExtension: "json"
	)
}
