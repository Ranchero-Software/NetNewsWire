//
//  FeedlyResourceId.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// The kinds of Resource Ids is documented here: https://developer.feedly.com/cloud/
protocol FeedlyResourceId {
	
	/// The resource Id from Feedly.
	var id: String { get }
}

/// The Feed Resource is documented here: https://developer.feedly.com/cloud/
struct FeedlyFeedResourceId: FeedlyResourceId {
	var id: String
	
	/// The location of the kind of resource a concrete type represents.
	/// If the conrete type cannot strip the resource type from the Id, it should just return the Id
	/// since the Id is a legitimate URL.
	var url: String {
		if let range = id.range(of: "feed/"), range.lowerBound == id.startIndex {
			var mutant = id
			mutant.removeSubrange(range)
			return mutant
		}
		
		// It seems values like "something/https://my.blog/posts.xml" is a legit URL.
		return id
	}
}

extension FeedlyFeedResourceId {
	init(url: String) {
		self.id = "feed/\(url)"
	}
}

struct FeedlyCategoryResourceId: FeedlyResourceId {
	var id: String
	
	static func uncategorized(for userId: String) -> FeedlyCategoryResourceId {
		// https://developer.feedly.com/cloud/#global-resource-ids
		let id = "user/\(userId)/category/global.uncategorized"
		return FeedlyCategoryResourceId(id: id)
	}
}

struct FeedlyTagResourceId: FeedlyResourceId {
	var id: String
	
	static func saved(for userId: String) -> FeedlyTagResourceId {
		// https://developer.feedly.com/cloud/#global-resource-ids
		let id = "user/\(userId)/tag/global.saved"
		return FeedlyTagResourceId(id: id)
	}
}
