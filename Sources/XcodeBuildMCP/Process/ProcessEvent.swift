//
//  ProcessEvent.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Foundation

// 하위 process의 표준 출력 조각과 종료 상태를 표현합니다.
package enum ProcessEvent: Sendable, Equatable {
	case standardOutput(Data)
	case terminated(Int32)
}
