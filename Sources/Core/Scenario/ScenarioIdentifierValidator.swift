//
//  ScenarioIdentifierValidator.swift
//  QALenz
//
//  Created by opfic on 8/14/26.
//

// scenario와 step id의 공통 형식을 검증합니다.
enum ScenarioIdentifierValidator {
	// 소문자와 숫자, 하이픈으로 구성한 scenario 식별자인지 반환합니다.
	static func isValid(_ id: String) -> Bool {
		guard let first = id.utf8.first else { return false }
		guard isLowercaseLetter(first) else { return false }

		var previousWasHyphen = false

		for byte in id.utf8 {
			let isAllowed = isLowercaseLetter(byte) || isNumber(byte) || byte == 45

			guard isAllowed else { return false }
			guard !(byte == 45 && previousWasHyphen) else { return false }
			previousWasHyphen = byte == 45
		}

		return !previousWasHyphen
	}

	// ASCII 소문자인지 반환합니다.
	private static func isLowercaseLetter(_ byte: UInt8) -> Bool {
		97 <= byte && byte <= 122
	}

	// ASCII 숫자인지 반환합니다.
	private static func isNumber(_ byte: UInt8) -> Bool {
		48 <= byte && byte <= 57
	}
}
