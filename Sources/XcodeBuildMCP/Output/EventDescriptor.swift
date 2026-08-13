//
//  EventDescriptor.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

// event 출력의 namespace와 operation을 보관합니다.
struct EventDescriptor: Sendable, Equatable {
	let namespace: String
	let operation: String
}
