//
//  FeedlyStream.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyStream: Decodable {
	var id: String
	var timestamp: Date?
	var continuation: String?
	var items: [FeedlyEntry]
	
	var isStreamEnd: Bool {
		return continuation == nil
	}
}
