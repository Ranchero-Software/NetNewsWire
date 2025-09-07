//
//  FeedTransformer.swift
//  Account
//
//  Created by Claude on 9/7/25.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser

/// Protocol for transforming feed content to add special functionality
/// like video embedding or content enhancement.
public protocol FeedTransformer {
	
	/// Determines if this transformer applies to the given feed URL
	/// - Parameter feedURL: The feed URL to check
	/// - Returns: True if this transformer should be applied to the feed
	func applies(to feedURL: String) -> Bool
	
	/// Corrects the feed URL if needed (e.g., YouTube channel page to RSS feed)
	/// - Parameter feedURL: The original feed URL
	/// - Returns: The corrected feed URL, or nil if no correction is needed
	func correctFeedURL(_ feedURL: String) -> String?
	
	/// Transforms the parsed feed content
	/// - Parameter parsedFeed: The original parsed feed
	/// - Returns: The transformed parsed feed
	func transform(_ parsedFeed: ParsedFeed) -> ParsedFeed
	
	/// Priority for applying transformers (higher numbers = higher priority)
	/// Used when multiple transformers apply to the same feed
	var priority: Int { get }
	
	/// Unique identifier for this transformer type
	var identifier: String { get }
}

/// Default implementations for convenience
public extension FeedTransformer {
	
	/// Default priority is 0 (lowest)
	var priority: Int { return 0 }
	
	/// Default identifier is the class name
	var identifier: String {
		return String(describing: type(of: self))
	}
}