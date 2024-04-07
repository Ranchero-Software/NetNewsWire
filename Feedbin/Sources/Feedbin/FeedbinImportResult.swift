//
//  FeedbinImportResult.swift
//  Account
//
//  Created by Maurice Parker on 5/17/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedbinImportResult: Codable, Sendable {

	public let importResultID: Int
	public let complete: Bool
	
	enum CodingKeys: String, CodingKey {
		case importResultID = "id"
		case complete
	}
	
}
