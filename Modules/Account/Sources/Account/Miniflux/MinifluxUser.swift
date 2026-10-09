//
//  MinifluxUser.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// GET /v1/me → {"id":35,"username":"claude","is_admin":false,...}
struct MinifluxUser: Decodable, Sendable {
	let id: Int64
	let username: String
}
