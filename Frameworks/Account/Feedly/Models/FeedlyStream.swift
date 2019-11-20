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
	
	/// Of the most recent entry for this stream (regardless of continuation, newerThan, etc).
	var updated: Date?
	
	/// Optional string the continuation id to pass to the next stream call, for pagination.
	/// This id guarantees that no entry will be duplicated in a stream (meaning, there is no need to de-duplicate entries returned by this call).
	/// If this value is not returned, it means the end of the stream has been reached.
	var continuation: String?
	var items: [FeedlyEntry]
	
	var isStreamEnd: Bool {
		return continuation == nil
	}
}
