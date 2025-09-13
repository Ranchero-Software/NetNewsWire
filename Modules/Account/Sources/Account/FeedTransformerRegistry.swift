//
//  FeedTransformerRegistry.swift
//  Account
//
//  Created by Claude on 9/7/25.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

/// Registry for managing and applying feed transformers
public final class FeedTransformerRegistry {
	
	public static let shared = FeedTransformerRegistry()
	
	private var transformers: [FeedTransformer] = []
	private let queue = DispatchQueue(label: "FeedTransformerRegistry", qos: .utility)
	
	private init() {}
	
	/// Registers a new feed transformer
	/// - Parameter transformer: The transformer to register
	public func register(_ transformer: FeedTransformer) {
		print("🔧 FeedTransformerRegistry: Registering transformer '\(transformer.identifier)' with priority \(transformer.priority)")
		queue.async {
			// Remove any existing transformer with the same identifier
			self.transformers.removeAll { $0.identifier == transformer.identifier }
			
			// Add the new transformer and sort by priority (highest first)
			self.transformers.append(transformer)
			self.transformers.sort { $0.priority > $1.priority }
			
			print("🔧 FeedTransformerRegistry: Now have \(self.transformers.count) registered transformers")
		}
	}
	
	/// Unregisters a transformer by identifier
	/// - Parameter identifier: The identifier of the transformer to remove
	public func unregister(identifier: String) {
		queue.async {
			self.transformers.removeAll { $0.identifier == identifier }
		}
	}
	
	/// Corrects a feed URL by applying the first applicable transformer
	/// - Parameter feedURL: The original feed URL
	/// - Returns: The corrected feed URL, or the original if no correction is needed
	public func correctFeedURL(_ feedURL: String) -> String {
		return queue.sync {
			for transformer in transformers {
				if transformer.applies(to: feedURL) {
					if let correctedURL = transformer.correctFeedURL(feedURL) {
						return correctedURL
					}
				}
			}
			return feedURL
		}
	}
	
	/// Transforms a parsed feed by applying all applicable transformers
	/// - Parameters:
	///   - parsedFeed: The original parsed feed
	///   - feedURL: The feed URL for determining applicable transformers
	/// - Returns: The transformed parsed feed
	public func transform(_ parsedFeed: ParsedFeed, feedURL: String) -> ParsedFeed {
		print("🔧 FeedTransformerRegistry: transform() called for feedURL: \(feedURL) with \(transformers.count) registered transformers")
		return queue.sync {
			var result = parsedFeed
			
			for transformer in transformers {
				print("🔧 FeedTransformerRegistry: checking transformer '\(transformer.identifier)'")
				if transformer.applies(to: feedURL) {
					print("🔧 FeedTransformerRegistry: applying transformer '\(transformer.identifier)'")
					result = transformer.transform(result)
				}
			}
			
			return result
		}
	}
	
	/// Returns all registered transformers (for testing/debugging)
	public func registeredTransformers() -> [FeedTransformer] {
		return queue.sync {
			return Array(transformers)
		}
	}
	
	/// Clears all registered transformers
	public func clearAll() {
		queue.async {
			self.transformers.removeAll()
		}
	}
}