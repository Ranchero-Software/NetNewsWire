//
//  TwitterList.swift
//  
//
//  Created by Maurice Parker on 8/14/20.
//

import Foundation

struct TwitterList: Codable {
	
	let name: String?

	enum CodingKeys: String, CodingKey {
		case name = "name"
	}
}
