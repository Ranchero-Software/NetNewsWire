//
//  MinifluxCategory.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// GET /v1/categories → [{"id":38,"title":"All","user_id":35,"hide_globally":false},...]
// A Miniflux category maps one-to-one to an NNW folder.
struct MinifluxCategory: Decodable, Sendable, Hashable {
	let categoryID: Int64
	let title: String

	enum CodingKeys: String, CodingKey {
		case categoryID = "id"
		case title
	}

	static func == (lhs: MinifluxCategory, rhs: MinifluxCategory) -> Bool {
		lhs.categoryID == rhs.categoryID
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(categoryID)
	}
}

// Used for both category creation and rename — Miniflux takes the same body for both.
struct MinifluxCategoryPayload: Encodable, Sendable {
	let title: String
}
