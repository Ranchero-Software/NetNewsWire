//
//  FeedlyResourceID.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// The kinds of Resource IDs is documented here: https://developer.feedly.com/cloud/
public protocol FeedlyResourceID {
	
	/// The resource ID from Feedly.
	@MainActor var id: String { get }
}

/// The Feed Resource is documented here: https://developer.feedly.com/cloud/
public struct FeedlyFeedResourceID: FeedlyResourceID, Sendable {

	public let id: String

	/// The location of the kind of resource a concrete type represents.
	/// If the concrete type cannot strip the resource type from the ID, it should just return the ID
	/// since the ID is a legitimate URL.
	/// This is basically assuming Feedly prefixes source feed URLs with `feed/`.
	/// It is not documented as such and could potentially change.
	/// Feedly does not include the source feed URL as a separate field.
	/// See https://developer.feedly.com/v3/feeds/#get-the-metadata-about-a-specific-feed
	public var url: String {
		if let range = id.range(of: "feed/"), range.lowerBound == id.startIndex {
			var mutant = id
			mutant.removeSubrange(range)
			return mutant
		}
		
		// It seems values like "something/https://my.blog/posts.xml" is a legit URL.
		return id
	}

	public init(id: String) {
		self.id = id
	}
}

extension FeedlyFeedResourceID {
	
	init(url: String) {
		self.id = "feed/\(url)"
	}
}

public struct FeedlyCategoryResourceID: FeedlyResourceID, Sendable {

	public let id: String

	public enum Global {

		public static func uncategorized(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.uncategorized"
			return FeedlyCategoryResourceID(id: id)
		}
		
		/// All articles from all the feeds the user subscribes to.
		public static func all(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.all"
			return FeedlyCategoryResourceID(id: id)
		}
		
		/// All articles from all the feeds the user loves most.
		public static func mustRead(for userID: String) -> FeedlyCategoryResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/category/global.must"
			return FeedlyCategoryResourceID(id: id)
		}
	}
}

public struct FeedlyTagResourceID: FeedlyResourceID, Sendable {

	public let id: String

	public enum Global {

		public static func saved(for userID: String) -> FeedlyTagResourceID {
			// https://developer.feedly.com/cloud/#global-resource-ids
			let id = "user/\(userID)/tag/global.saved"
			return FeedlyTagResourceID(id: id)
		}
	}
}
