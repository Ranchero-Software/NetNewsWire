//
//  FeedlyResourceId.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// The kinds of Resource Ids is documented here: https://developer.feedly.com/cloud/
protocol FeedlyResourceID {
	
	/// The resource Id from Feedly.
	var id: String { get }
}

/// The Feed Resource is documented here: https://developer.feedly.com/cloud/
struct FeedlyFeedResourceID: FeedlyResourceID {
	let id: String
	
	/// The location of the kind of resource a concrete type represents.
	/// If the concrete type cannot strip the resource type from the Id, it should just return the Id
	/// since the Id is a legitimate URL.
	/// This is basically assuming Feedly prefixes source feed URLs with `feed/`.
	/// It is not documented as such and could potentially change.
	/// Feedly does not include the source feed URL as a separate field.
	/// See https://developer.feedly.com/v3/feeds/#get-the-metadata-about-a-specific-feed
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

extension FeedlyFeedResourceID {
	init(url: String) {
		self.id = "feed/\(url)"
	}
}

struct FeedlyCategoryResourceID: FeedlyResourceID {
	let id: String
	
	enum Global {
		
		static func uncategorized(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.uncategorized"
			return FeedlyCategoryResourceID(id: id)
		}
		
		/// All articles from all the feeds the user subscribes to.
		static func all(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.all"
			return FeedlyCategoryResourceID(id: id)
		}
		
		/// All articles from all the feeds the user loves most.
		static func mustRead(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.must"
			return FeedlyCategoryResourceID(id: id)
		}
	}
}

struct FeedlyTagResourceId: FeedlyResourceID {
	let id: String
	
	enum Global {
		
		static func saved(for userID: String) -> FeedlyTagResourceId {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/tag/global.saved"
			return FeedlyTagResourceId(id: id)
		}
	}
}
