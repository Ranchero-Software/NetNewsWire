//
//  String+Parser.swift
//  Parser
//
//  Created by Nate Weaver on 2020-01-19.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension String {

	var nilIfEmptyOrWhitespace: String? {
		return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
	}

	static func isEmptyOrNil(_ s: String?) -> Bool {
		if let s {
			return s.isEmpty
		}
		return true
	}
}
