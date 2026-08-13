//
//  QALenzConfigurationSchema.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// QALenz configuration JSON Schema resource를 제공합니다.
package enum QALenzConfigurationSchema {
	// 모듈 bundle에 포함된 schema resource의 URL입니다.
	package static let resourceURL = Bundle.module.url(
		forResource: "qalenz-config.schema",
		withExtension: "json"
	)
}
