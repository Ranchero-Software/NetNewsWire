//
//  TwitterSymbol.swift
//  Account
//
//  Created by Maurice Parker on 4/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct TwitterSymbol: Codable, TwitterEntity {
	
	let name: String?
	let indices: [Int]?

	enum CodingKeys: String, CodingKey {
		case name = "name"
		case indices = "indices"
	}
	
	var startIndex: Int {
		if let indices = indices, indices.count > 0 {
			return indices[0] - 1
		}
		return 0
	}
	
	func renderAsHTML() -> String {
		return ""
	}
	
}
