//
//  FeedlyStreamIds.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyStreamIds: Decodable {
	let continuation: String?
	let ids: [String]
	
	var isStreamEnd: Bool {
		return continuation == nil
	}
}
