//
//  FeedlyStreamIds.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

nonisolated struct FeedlyStreamIds: Decodable, Sendable {
	let continuation: String?
	let ids: [String]

	var isStreamEnd: Bool {
		return continuation == nil
	}
}
