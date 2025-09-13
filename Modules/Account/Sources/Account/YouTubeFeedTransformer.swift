//
//  YouTubeFeedTransformer.swift
//  Account
//
//  Created by Claude on 9/7/25.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

/// Transformer for YouTube feeds that adds inline video embedding
public final class YouTubeFeedTransformer: FeedTransformer {
	
	public var priority: Int { return 100 } // High priority for YouTube feeds
	public var identifier: String { return "YouTubeFeedTransformer" }
	
	// YouTube URL patterns
	private static let channelPatterns = [
		"youtube.com/channel/",
		"youtube.com/c/",
		"youtube.com/@",
		"youtube.com/user/",
		"www.youtube.com/channel/",
		"www.youtube.com/c/", 
		"www.youtube.com/@",
		"www.youtube.com/user/"
	]
	
	private static let feedPatterns = [
		"youtube.com/feeds/",
		"www.youtube.com/feeds/"
	]
	
	public init() {}
	
	// MARK: - FeedTransformer Protocol
	
	public func applies(to feedURL: String) -> Bool {
		let lowercaseURL = feedURL.lowercased()
		
		// Check if it's already a YouTube feed URL or a channel/user page
		let applies = Self.channelPatterns.contains { lowercaseURL.contains($0) } ||
					  Self.feedPatterns.contains { lowercaseURL.contains($0) }
		
		print("🎬 YouTubeFeedTransformer.applies(to: \"\(feedURL)\") = \(applies)")
		return applies
	}
	
	public func correctFeedURL(_ feedURL: String) -> String? {
		guard applies(to: feedURL) else { return nil }
		
		let lowercaseURL = feedURL.lowercased()
		
		// If it's already a feed URL, don't change it
		if Self.feedPatterns.contains(where: { lowercaseURL.contains($0) }) {
			return nil
		}
		
		// Convert channel/user URLs to RSS feed URLs
		return convertToFeedURL(feedURL)
	}
	
	public func transform(_ parsedFeed: ParsedFeed) -> ParsedFeed {
		print("🎬 YouTubeFeedTransformer: transforming feed with \(parsedFeed.items.count) items")
		let transformedItems = Set(parsedFeed.items.map { transformItem($0) })
		
		return ParsedFeed(
			type: parsedFeed.type,
			title: parsedFeed.title,
			homePageURL: parsedFeed.homePageURL,
			feedURL: parsedFeed.feedURL,
			language: parsedFeed.language,
			feedDescription: parsedFeed.feedDescription,
			nextURL: parsedFeed.nextURL,
			iconURL: parsedFeed.iconURL,
			faviconURL: parsedFeed.faviconURL,
			authors: parsedFeed.authors,
			expired: parsedFeed.expired,
			hubs: parsedFeed.hubs,
			items: transformedItems
		)
	}
	
	// MARK: - Private Implementation
	
	private func convertToFeedURL(_ originalURL: String) -> String? {
		// Extract channel ID or username from various YouTube URL formats
		if let channelID = extractChannelID(from: originalURL) {
			return "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)"
		}
		
		if let username = extractUsername(from: originalURL) {
			// For username-based URLs, we need to convert to channel ID first
			// For now, return the username-based feed URL format
			return "https://www.youtube.com/feeds/videos.xml?user=\(username)"
		}
		
		return nil
	}
	
	internal func transformItem(_ item: ParsedItem) -> ParsedItem {
		// Check if the item URL is a YouTube video URL
		if let itemURL = item.url,
		   let videoID = extractVideoIDFromURL(itemURL) {
			print("🎬 Found YouTube video: \(videoID) from URL: \(itemURL)")
			// For YouTube RSS feeds, embed the video based on the item URL
			let videoEmbed = createVideoEmbedHTML(videoID: videoID, item: item)
			let existingContent = item.contentHTML ?? ""
			let transformedHTML = existingContent.isEmpty ? videoEmbed : videoEmbed + "\n\n" + existingContent
			
			return ParsedItem(
				syncServiceID: item.syncServiceID,
				uniqueID: item.uniqueID,
				feedURL: item.feedURL,
				url: item.url,
				externalURL: item.externalURL,
				title: item.title,
				language: item.language,
				contentHTML: transformedHTML,
				contentText: item.contentText,
				summary: item.summary,
				imageURL: item.imageURL,
				bannerImageURL: item.bannerImageURL,
				datePublished: item.datePublished,
				dateModified: item.dateModified,
				authors: item.authors,
				tags: item.tags,
				attachments: item.attachments
			)
		} else if let contentHTML = item.contentHTML {
			print("🎬 Checking content HTML for YouTube URLs...")
			// Fall back to transforming YouTube URLs in the content (for other feed types)
			let transformedHTML = embedYouTubeVideos(in: contentHTML)
			if transformedHTML != contentHTML {
				print("🎬 Found and transformed YouTube URLs in content")
			}
			
			return ParsedItem(
				syncServiceID: item.syncServiceID,
				uniqueID: item.uniqueID,
				feedURL: item.feedURL,
				url: item.url,
				externalURL: item.externalURL,
				title: item.title,
				language: item.language,
				contentHTML: transformedHTML,
				contentText: item.contentText,
				summary: item.summary,
				imageURL: item.imageURL,
				bannerImageURL: item.bannerImageURL,
				datePublished: item.datePublished,
				dateModified: item.dateModified,
				authors: item.authors,
				tags: item.tags,
				attachments: item.attachments
			)
		}
		
		// No transformation needed - return original item
		return item
	}
	
	private func extractVideoIDFromURL(_ url: String) -> String? {
		// Extract video ID from YouTube video URLs
		let patterns = [
			"youtube\\.com/watch\\?v=([A-Za-z0-9_-]{11})",
			"www\\.youtube\\.com/watch\\?v=([A-Za-z0-9_-]{11})",
			"youtu\\.be/([A-Za-z0-9_-]{11})",
			"youtube\\.com/embed/([A-Za-z0-9_-]{11})",
			"www\\.youtube\\.com/embed/([A-Za-z0-9_-]{11})"
		]
		
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			   let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url)) {
				let range = Range(match.range(at: 1), in: url)!
				return String(url[range])
			}
		}
		
		return nil
	}
	
	private func extractChannelID(from url: String) -> String? {
		// Extract channel ID from URLs like:
		// https://youtube.com/channel/UCxxxxxxxxxxxxxxx
		// https://www.youtube.com/channel/UCxxxxxxxxxxxxxxx
		let patterns = [
			"youtube\\.com/channel/([A-Za-z0-9_-]+)",
			"www\\.youtube\\.com/channel/([A-Za-z0-9_-]+)"
		]
		
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			   let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url)) {
				let range = Range(match.range(at: 1), in: url)!
				return String(url[range])
			}
		}
		
		return nil
	}
	
	private func extractUsername(from url: String) -> String? {
		// Extract username from URLs like:
		// https://youtube.com/@username
		// https://youtube.com/user/username
		// https://youtube.com/c/channelname
		let patterns = [
			"youtube\\.com/@([A-Za-z0-9_-]+)",
			"www\\.youtube\\.com/@([A-Za-z0-9_-]+)",
			"youtube\\.com/user/([A-Za-z0-9_-]+)",
			"www\\.youtube\\.com/user/([A-Za-z0-9_-]+)",
			"youtube\\.com/c/([A-Za-z0-9_-]+)",
			"www\\.youtube\\.com/c/([A-Za-z0-9_-]+)"
		]
		
		for pattern in patterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
			   let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url)) {
				let range = Range(match.range(at: 1), in: url)!
				return String(url[range])
			}
		}
		
		return nil
	}
	
	private func embedYouTubeVideos(in html: String) -> String {
		// Find YouTube video URLs and replace with embedded video players
		let patterns = [
			"https://www\\.youtube\\.com/watch\\?v=([A-Za-z0-9_-]{11})",
			"https://youtube\\.com/watch\\?v=([A-Za-z0-9_-]{11})",
			"https://youtu\\.be/([A-Za-z0-9_-]{11})",
			"https://www\\.youtube\\.com/embed/([A-Za-z0-9_-]{11})"
		]
		
		var result = html
		
		for pattern in patterns {
			guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
				continue
			}
			
			let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
			
			// Process matches in reverse order to avoid range issues
			for match in matches.reversed() {
				guard let fullRange = Range(match.range, in: result),
					  let videoIDRange = Range(match.range(at: 1), in: result) else {
					continue
				}
				
				let videoID = String(result[videoIDRange])
				let embedHTML = createVideoEmbedHTML(videoID: videoID)
				result.replaceSubrange(fullRange, with: embedHTML)
			}
		}
		
		return result
	}
	
	private func createVideoEmbedHTML(videoID: String, item: ParsedItem? = nil) -> String {
		// Try different parameters to work around CSP issues
		let embedParams = [
			"html5=1",           // Force HTML5 player
			"playsinline=1",     // Inline playback
			"rel=0",             // No related videos
			"modestbranding=1",  // Minimal YouTube branding
			"enablejsapi=0",     // Disable JavaScript API (might help with CSP)
			"controls=1",        // Show player controls
			"disablekb=1",       // Disable keyboard controls (less JS)
			"fs=1",              // Allow fullscreen
			"iv_load_policy=3"   // Hide annotations (less JS)
		].joined(separator: "&")
		
		return """
		<div class="youtube-embed" style="position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; max-width: 100%; margin: 1em 0;">
			<iframe 
				src="https://www.youtube.com/embed/\(videoID)?\(embedParams)" 
				style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;"
				frameborder="0" 
				allowfullscreen
				allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
				sandbox="allow-scripts allow-same-origin allow-presentation allow-forms"
				referrerpolicy="no-referrer-when-downgrade">
			</iframe>
		</div>
		"""
	}
	
}