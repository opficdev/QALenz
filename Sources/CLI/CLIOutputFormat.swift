//
//  CLIOutputFormat.swift
//  QALenz
//
//  Created by opfic on 8/12/26.
//

import ArgumentParser

package enum CLIOutputFormat: String, Codable, Sendable, Equatable, ExpressibleByArgument {
	case text
	case json

	package static func requested(in arguments: [String]) -> Self {
		for (index, argument) in arguments.enumerated() {
			guard argument != "--" else { break }

			if argument == "--output=json" {
				return .json
			}

			if argument == "--output",
				arguments.indices.contains(index + 1),
				arguments[index + 1] == "json" {
				return .json
			}
		}

		return .text
	}
}
