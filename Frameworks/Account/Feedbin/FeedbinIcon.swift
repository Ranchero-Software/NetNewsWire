//
//  FeedbinIcon.swift
//  Account
//
//  Created by Maurice Parker on 5/6/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinIcon: Codable {
	
	let host: String
	let url: String
	
	enum CodingKeys: String, CodingKey {
		case host
		case url
	}
	
}
