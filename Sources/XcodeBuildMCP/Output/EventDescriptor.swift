//
//  EventDescriptor.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// event 출력의 namespace와 operation을 보관합니다.
package struct EventDescriptor: Sendable, Equatable {
	package let namespace: String
	package let operation: String

	// event namespace와 operation으로 descriptor를 구성합니다.
	package init(namespace: String, operation: String) {
		self.namespace = namespace
		self.operation = operation
	}
}
