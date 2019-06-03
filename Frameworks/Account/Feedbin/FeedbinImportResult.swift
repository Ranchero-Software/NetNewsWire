//
//  FeedbinImportResult.swift
//  Account
//
//  Created by Maurice Parker on 5/17/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedbinImportResult: Codable {
	
	let importResultID: Int
	let complete: Bool
	
	enum CodingKeys: String, CodingKey {
		case importResultID = "id"
		case complete
	}
	
}
