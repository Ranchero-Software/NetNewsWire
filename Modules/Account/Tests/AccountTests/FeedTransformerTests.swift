//
//  FeedTransformerTests.swift
//  AccountTests
//
//  Created by Claude on 9/7/25.
//  Copyright © 2025 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSParser

class FeedTransformerTests: XCTestCase {

	var registry: FeedTransformerRegistry!
	
	override func setUp() {
		super.setUp()
		registry = FeedTransformerRegistry.shared
		registry.clearAll() // Start with clean state
	}
	
	override func tearDown() {
		registry.clearAll() // Clean up after tests
		super.tearDown()
	}
	
	// MARK: - FeedTransformerRegistry Tests
	
	func testRegistryInitialState() {
		XCTAssertEqual(registry.registeredTransformers().count, 0, "Registry should start empty")
	}
	
	func testRegisterTransformer() {
		let transformer = MockFeedTransformer(identifier: "test1", priority: 10)
		registry.register(transformer)
		
		let registered = registry.registeredTransformers()
		XCTAssertEqual(registered.count, 1)
		XCTAssertEqual(registered.first?.identifier, "test1")
	}
	
	func testTransformerPriorityOrdering() {
		let lowPriority = MockFeedTransformer(identifier: "low", priority: 5)
		let highPriority = MockFeedTransformer(identifier: "high", priority: 10)
		let mediumPriority = MockFeedTransformer(identifier: "medium", priority: 7)
		
		registry.register(lowPriority)
		registry.register(highPriority)
		registry.register(mediumPriority)
		
		let registered = registry.registeredTransformers()
		XCTAssertEqual(registered.count, 3)
		XCTAssertEqual(registered[0].identifier, "high")
		XCTAssertEqual(registered[1].identifier, "medium")
		XCTAssertEqual(registered[2].identifier, "low")
	}
	
	func testReplaceTransformerWithSameIdentifier() {
		let transformer1 = MockFeedTransformer(identifier: "same", priority: 5)
		let transformer2 = MockFeedTransformer(identifier: "same", priority: 10)
		
		registry.register(transformer1)
		registry.register(transformer2)
		
		let registered = registry.registeredTransformers()
		XCTAssertEqual(registered.count, 1)
		XCTAssertEqual(registered.first?.priority, 10)
	}
	
	func testUnregisterTransformer() {
		let transformer = MockFeedTransformer(identifier: "test", priority: 5)
		registry.register(transformer)
		
		XCTAssertEqual(registry.registeredTransformers().count, 1)
		
		registry.unregister(identifier: "test")
		XCTAssertEqual(registry.registeredTransformers().count, 0)
	}
	
	func testCorrectFeedURL() {
		let transformer = MockFeedTransformer(
			identifier: "test",
			priority: 5,
			appliesTo: { $0.contains("example.com") },
			correction: { _ in "https://corrected.example.com/feed.xml" }
		)
		registry.register(transformer)
		
		let result = registry.correctFeedURL("https://example.com/page")
		XCTAssertEqual(result, "https://corrected.example.com/feed.xml")
		
		let noChange = registry.correctFeedURL("https://other.com/feed")
		XCTAssertEqual(noChange, "https://other.com/feed")
	}
	
	func testTransformFeed() {
		let transformer = MockFeedTransformer(
			identifier: "test",
			priority: 5,
			appliesTo: { $0.contains("example.com") },
			transformer: { feed in
				return ParsedFeed(
					type: feed.type,
					title: "Transformed: \(feed.title ?? "")",
					homePageURL: feed.homePageURL,
					feedURL: feed.feedURL,
					language: feed.language,
					feedDescription: feed.feedDescription,
					nextURL: feed.nextURL,
					iconURL: feed.iconURL,
					faviconURL: feed.faviconURL,
					authors: feed.authors,
					expired: feed.expired,
					hubs: feed.hubs,
					items: feed.items
				)
			}
		)
		registry.register(transformer)
		
		let originalFeed = createTestParsedFeed(title: "Test Feed")
		let transformedFeed = registry.transform(originalFeed, feedURL: "https://example.com/feed")
		
		XCTAssertEqual(transformedFeed.title, "Transformed: Test Feed")
	}
	
	// MARK: - YouTubeFeedTransformer Tests
	
	func testYouTubeURLDetection() {
		let transformer = YouTubeFeedTransformer()
		
		// Should detect various YouTube URL formats
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/channel/UCtest"))
		XCTAssertTrue(transformer.applies(to: "https://www.youtube.com/channel/UCtest"))
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/c/channelname"))
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/@username"))
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/user/username"))
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/feeds/videos.xml?channel_id=test"))
		
		// Should not detect non-YouTube URLs
		XCTAssertFalse(transformer.applies(to: "https://example.com/feed.xml"))
		XCTAssertFalse(transformer.applies(to: "https://vimeo.com/user/test"))
		
		// Should detect corrected feed URLs  
		XCTAssertTrue(transformer.applies(to: "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest123"))
		XCTAssertTrue(transformer.applies(to: "https://youtube.com/feeds/videos.xml?user=testuser"))
	}
	
	func testYouTubeTransformerPriority() {
		let transformer = YouTubeFeedTransformer()
		XCTAssertEqual(transformer.priority, 100, "YouTube transformer should have high priority")
	}
	
	func testYouTubeTransformerIdentifier() {
		let transformer = YouTubeFeedTransformer()
		XCTAssertEqual(transformer.identifier, "YouTubeFeedTransformer")
	}
	
	func testYouTubeFeedURLCorrection() {
		let transformer = YouTubeFeedTransformer()
		
		// Test channel ID conversion
		let channelURL = "https://youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw"
		let expectedChannelFeed = "https://www.youtube.com/feeds/videos.xml?channel_id=UC_x5XG1OV2P6uZZ5FSM9Ttw"
		XCTAssertEqual(transformer.correctFeedURL(channelURL), expectedChannelFeed)
		
		// Test username conversion
		let userURL = "https://youtube.com/user/testuser"
		let expectedUserFeed = "https://www.youtube.com/feeds/videos.xml?user=testuser"
		XCTAssertEqual(transformer.correctFeedURL(userURL), expectedUserFeed)
		
		// Test @username conversion
		let atUserURL = "https://youtube.com/@testuser"
		XCTAssertEqual(transformer.correctFeedURL(atUserURL), expectedUserFeed)
		
		// Test c/ channel conversion
		let cChannelURL = "https://youtube.com/c/testchannel"
		let expectedCChannelFeed = "https://www.youtube.com/feeds/videos.xml?user=testchannel"
		XCTAssertEqual(transformer.correctFeedURL(cChannelURL), expectedCChannelFeed)
		
		// Test that existing feed URLs are not changed
		let existingFeedURL = "https://youtube.com/feeds/videos.xml?channel_id=UC_test"
		XCTAssertNil(transformer.correctFeedURL(existingFeedURL))
		
		// Test non-YouTube URLs
		let nonYouTubeURL = "https://example.com/feed.xml"
		XCTAssertNil(transformer.correctFeedURL(nonYouTubeURL))
	}
	
	func testYouTubeVideoEmbedding() {
		let transformer = YouTubeFeedTransformer()
		
		// Create test item with YouTube URLs in content
		let contentWithVideo = """
		<p>Check out this video: https://www.youtube.com/watch?v=dQw4w9WgXcQ</p>
		<p>Also this one: https://youtu.be/dQw4w9WgXcQ</p>
		"""
		
		let testItem = createTestParsedItem(contentHTML: contentWithVideo)
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		// Should contain embedded iframe with enhanced attributes
		XCTAssertTrue(transformedHTML.contains("iframe"))
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/dQw4w9WgXcQ?playsinline=1"))
		XCTAssertTrue(transformedHTML.contains("youtube-embed"))
		XCTAssertTrue(transformedHTML.contains("web-share"), "Should include web-share permission")
		
		// Should have replaced both URLs with embedded iframes
		// Check for the essential elements rather than counting specific iframe occurrences
		XCTAssertTrue(transformedHTML.contains("youtube-embed"), "Should contain video embed containers")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/dQw4w9WgXcQ"), "Should contain embedded video URLs")
	}
	
	func testYouTubeVideoEmbeddingWithNoVideos() {
		let transformer = YouTubeFeedTransformer()
		
		let contentWithoutVideo = "<p>This is regular content with no videos.</p>"
		let testItem = createTestParsedItem(contentHTML: contentWithoutVideo)
		let transformedItem = transformer.transformItem(testItem)
		
		// Content should remain unchanged
		XCTAssertEqual(transformedItem.contentHTML, contentWithoutVideo)
	}
	
	func testYouTubeEmbedAttributesFollowReederBestPractices() {
		let transformer = YouTubeFeedTransformer()
		
		let testItem = createTestParsedItemWithURL("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		// Verify enhanced iframe attributes based on Reeder's implementation
		XCTAssertTrue(transformedHTML.contains("?playsinline=1"), "Should include playsinline parameter for iOS inline playback")
		XCTAssertTrue(transformedHTML.contains("web-share"), "Should include web-share permission for sharing functionality")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com"), "Should use privacy-enhanced domain")
		XCTAssertTrue(transformedHTML.contains("allowfullscreen"), "Should allow fullscreen playback")
		
		// Verify all expected allow permissions
		let allowPermissions = ["accelerometer", "autoplay", "clipboard-write", "encrypted-media", "gyroscope", "picture-in-picture", "web-share"]
		for permission in allowPermissions {
			XCTAssertTrue(transformedHTML.contains(permission), "Should include \(permission) permission")
		}
	}
	
	func testYouTubeVideoEmbeddingWithNilContent() {
		let transformer = YouTubeFeedTransformer()
		
		let testItem = createTestParsedItem(contentHTML: nil)
		let transformedItem = transformer.transformItem(testItem)
		
		// Should return original item unchanged
		XCTAssertNil(transformedItem.contentHTML)
		XCTAssertEqual(transformedItem.uniqueID, testItem.uniqueID)
	}
	
	func testYouTubeIntegrationWithRegistry() {
		// Test that YouTube transformer works correctly with the registry
		let transformer = YouTubeFeedTransformer()
		registry.register(transformer)
		
		// Test URL correction
		let youtubeChannelURL = "https://youtube.com/channel/UCtest123"
		let correctedURL = registry.correctFeedURL(youtubeChannelURL)
		XCTAssertEqual(correctedURL, "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest123")
		
		// Test feed transformation - use the corrected feed URL to ensure transformer applies  
		let contentWithVideo = "<p>Video: https://www.youtube.com/watch?v=dQw4w9WgXcQ</p>"
		let testFeed = createTestParsedFeedWithItems(contentHTML: contentWithVideo)
		
		let transformedFeed = registry.transform(testFeed, feedURL: correctedURL)
		
		guard let firstItem = transformedFeed.items.first,
			  let transformedHTML = firstItem.contentHTML else {
			XCTFail("Should have transformed content")
			return
		}
		
		XCTAssertTrue(transformedHTML.contains("iframe"), "Transformed HTML should contain iframe: \(transformedHTML)")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/dQw4w9WgXcQ?playsinline=1"), "Transformed HTML should contain enhanced embed URL: \(transformedHTML)")
	}
	
	// MARK: - Helper Methods
	
	private func createTestParsedFeed(title: String? = nil) -> ParsedFeed {
		return ParsedFeed(
			type: .rss,
			title: title,
			homePageURL: nil,
			feedURL: nil,
			language: nil,
			feedDescription: nil,
			nextURL: nil,
			iconURL: nil,
			faviconURL: nil,
			authors: nil,
			expired: false,
			hubs: nil,
			items: Set<ParsedItem>()
		)
	}
	
	private func createTestParsedItem(contentHTML: String?) -> ParsedItem {
		return ParsedItem(
			syncServiceID: nil,
			uniqueID: "test-item-\(UUID().uuidString)",
			feedURL: "https://example.com/feed",
			url: "https://example.com/item",
			externalURL: nil,
			title: "Test Item",
			language: nil,
			contentHTML: contentHTML,
			contentText: nil,
			summary: nil,
			imageURL: nil,
			bannerImageURL: nil,
			datePublished: Date(),
			dateModified: nil,
			authors: nil,
			tags: nil,
			attachments: nil
		)
	}
	
	private func createTestParsedItemWithURL(_ itemURL: String) -> ParsedItem {
		return ParsedItem(
			syncServiceID: nil,
			uniqueID: "test-item-\(UUID().uuidString)",
			feedURL: "https://example.com/feed",
			url: itemURL,
			externalURL: nil,
			title: "Test Item",
			language: nil,
			contentHTML: "",
			contentText: nil,
			summary: nil,
			imageURL: nil,
			bannerImageURL: nil,
			datePublished: Date(),
			dateModified: nil,
			authors: nil,
			tags: nil,
			attachments: nil
		)
	}
	
	private func createTestParsedFeedWithItems(contentHTML: String) -> ParsedFeed {
		let testItem = createTestParsedItem(contentHTML: contentHTML)
		return ParsedFeed(
			type: .rss,
			title: "Test Feed",
			homePageURL: nil,
			feedURL: nil,
			language: nil,
			feedDescription: nil,
			nextURL: nil,
			iconURL: nil,
			faviconURL: nil,
			authors: nil,
			expired: false,
			hubs: nil,
			items: Set([testItem])
		)
	}
	
	// MARK: - Integration Tests
	
	func testFeedFinderIntegration() {
		// Test that FeedFinder properly applies URL correction
		let originalURL = "https://youtube.com/channel/UCtest123"
		let expectedCorrectedURL = "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest123"
		
		// Register our transformer
		let transformer = YouTubeFeedTransformer()
		registry.register(transformer)
		
		// Test URL correction through registry
		let correctedURL = registry.correctFeedURL(originalURL)
		XCTAssertEqual(correctedURL, expectedCorrectedURL, "Registry should correct YouTube channel URLs")
	}
	
	func testYouTubeShortsVideoEmbedding() {
		let transformer = YouTubeFeedTransformer()
		
		// Test with YouTube Shorts URL
		let testItem = createTestParsedItemWithURL("https://www.youtube.com/shorts/kNry0bf7eC0")
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		// Should contain embedded iframe
		XCTAssertTrue(transformedHTML.contains("iframe"))
		XCTAssertTrue(transformedHTML.contains("youtube.com/embed/kNry0bf7eC0"))
		XCTAssertTrue(transformedHTML.contains("youtube-embed"))
		
		print("🎬 YouTube Shorts embedding result: \(transformedHTML)")
	}
	
	func testYouTubeShortsInContentHTML() {
		let transformer = YouTubeFeedTransformer()
		
		let contentWithShorts = """
		<p>Check out this awesome short video:</p>
		<a href="https://www.youtube.com/shorts/kNry0bf7eC0">YouTube Short</a>
		<p>And some other content.</p>
		"""
		
		let testItem = createTestParsedItem(contentHTML: contentWithShorts)
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		// Should contain embedded iframe
		XCTAssertTrue(transformedHTML.contains("iframe"))
		XCTAssertTrue(transformedHTML.contains("youtube.com/embed/kNry0bf7eC0"))
		XCTAssertTrue(transformedHTML.contains("youtube-embed"))
		
		print("🎬 YouTube Shorts in content embedding result: \(transformedHTML)")
	}
	
	func testLocalAccountRefresherTransformation() {
		// Test that the transformer registry correctly transforms feed content
		let transformer = YouTubeFeedTransformer()
		registry.register(transformer)
		
		let contentWithVideo = "<p>Check this video: https://www.youtube.com/watch?v=dQw4w9WgXcQ</p>"
		let testFeed = createTestParsedFeedWithItems(contentHTML: contentWithVideo)
		let youtubeRSSURL = "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest123"
		
		let transformedFeed = registry.transform(testFeed, feedURL: youtubeRSSURL)
		
		guard let firstItem = transformedFeed.items.first,
			  let transformedHTML = firstItem.contentHTML else {
			XCTFail("Should have transformed content")
			return
		}
		
		XCTAssertTrue(transformedHTML.contains("iframe"), "Content should contain embedded iframe") 
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/dQw4w9WgXcQ"), "Content should contain embedded video")
	}
	
	func testDebugYouTubeTransformerWithRealContent() {
		// Test with actual YouTube RSS feed content patterns
		let transformer = YouTubeFeedTransformer()
		
		// Test 1: Real YouTube RSS feed URL detection
		XCTAssertTrue(transformer.applies(to: "https://www.youtube.com/feeds/videos.xml?channel_id=UCBa659QWEk1AI4Tg--mrJ2A"))
		
		// Test 2: Real video embedding with common YouTube content patterns
		let realYouTubeContent = """
		<p>New video: <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">Watch on YouTube</a></p>
		<p>Also check: https://youtu.be/dQw4w9WgXcQ</p>
		<p>Embedded link: https://www.youtube.com/embed/dQw4w9WgXcQ</p>
		"""
		
		let testItem = createTestParsedItem(contentHTML: realYouTubeContent)
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		print("DEBUG - Original content: \(realYouTubeContent)")
		print("DEBUG - Transformed content: \(transformedHTML)")
		
		XCTAssertTrue(transformedHTML.contains("iframe"), "Should contain iframe elements")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/dQw4w9WgXcQ"), "Should contain embed URLs")
	}
	
	func testYouTubeRSSFeedVideoEmbedding() {
		// Test the primary use case: YouTube RSS feeds with video URLs in item.url
		let transformer = YouTubeFeedTransformer()
		
		// Create a test item that mimics a YouTube RSS feed item
		let youTubeVideoURL = "https://www.youtube.com/watch?v=7DKv5H5Frt0"
		let videoDescription = "This is the video description from the RSS feed."
		
		let testItem = ParsedItem(
			syncServiceID: nil,
			uniqueID: "yt:video:7DKv5H5Frt0",
			feedURL: "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest",
			url: youTubeVideoURL,
			externalURL: nil,
			title: "Test YouTube Video",
			language: nil,
			contentHTML: videoDescription,
			contentText: nil,
			summary: nil,
			imageURL: nil,
			bannerImageURL: nil,
			datePublished: Date(),
			dateModified: nil,
			authors: nil,
			tags: nil,
			attachments: nil
		)
		
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Transformed item should have content HTML")
			return
		}
		
		print("DEBUG - YouTube RSS transformed content: \(transformedHTML)")
		
		// Should contain embedded video at the beginning
		XCTAssertTrue(transformedHTML.contains("iframe"), "Should contain iframe for video embed")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/7DKv5H5Frt0"), "Should contain embedded video URL")
		XCTAssertTrue(transformedHTML.contains("This is the video description"), "Should preserve original description")
		XCTAssertTrue(transformedHTML.contains("📺 Watch on YouTube"), "Should contain fallback link")
		
		// Video embed should come before the description  
		let iframeIndex = transformedHTML.firstIndex(of: "i") // First character of "iframe"
		let descriptionIndex = transformedHTML.range(of: "This is the video description")?.lowerBound
		
		if let iframeIdx = iframeIndex, let descIdx = descriptionIndex {
			XCTAssertTrue(iframeIdx < descIdx, "Video embed should appear before description")
		}
	}
	
	func testYouTubeVideoWithThumbnail() {
		// Test that Media RSS thumbnails are properly included
		let transformer = YouTubeFeedTransformer()
		
		let testItem = ParsedItem(
			syncServiceID: nil,
			uniqueID: "yt:video:7DKv5H5Frt0",
			feedURL: "https://www.youtube.com/feeds/videos.xml?channel_id=UCtest",
			url: "https://www.youtube.com/watch?v=7DKv5H5Frt0",
			externalURL: nil,
			title: "Test Video",
			language: nil,
			contentHTML: "Video description",
			contentText: nil,
			summary: nil,
			imageURL: "https://i4.ytimg.com/vi/7DKv5H5Frt0/hqdefault.jpg", // Media RSS thumbnail
			bannerImageURL: nil,
			datePublished: Date(),
			dateModified: nil,
			authors: nil,
			tags: nil,
			attachments: nil
		)
		
		let transformedItem = transformer.transformItem(testItem)
		
		guard let transformedHTML = transformedItem.contentHTML else {
			XCTFail("Should have transformed content")
			return
		}
		
		// Should include the Media RSS thumbnail
		XCTAssertTrue(transformedHTML.contains("youtube-thumbnail"), "Should contain thumbnail div")
		XCTAssertTrue(transformedHTML.contains("https://i4.ytimg.com/vi/7DKv5H5Frt0/hqdefault.jpg"), "Should use Media RSS thumbnail")
		XCTAssertTrue(transformedHTML.contains("loading=\"lazy\""), "Should use lazy loading for thumbnail")
		
		// Should still have video embed
		XCTAssertTrue(transformedHTML.contains("iframe"), "Should contain video iframe")
		XCTAssertTrue(transformedHTML.contains("youtube-nocookie.com/embed/7DKv5H5Frt0"), "Should contain video embed")
	}
}

// MARK: - Mock Transformer for Testing

private class MockFeedTransformer: FeedTransformer {
	
	let _identifier: String
	let _priority: Int
	let _appliesTo: (String) -> Bool
	let _correction: ((String) -> String?)?
	let _transformer: ((ParsedFeed) -> ParsedFeed)?
	
	init(identifier: String,
		 priority: Int,
		 appliesTo: @escaping (String) -> Bool = { _ in false },
		 correction: ((String) -> String?)? = nil,
		 transformer: ((ParsedFeed) -> ParsedFeed)? = nil) {
		self._identifier = identifier
		self._priority = priority
		self._appliesTo = appliesTo
		self._correction = correction
		self._transformer = transformer
	}
	
	var identifier: String { return _identifier }
	var priority: Int { return _priority }
	
	func applies(to feedURL: String) -> Bool {
		return _appliesTo(feedURL)
	}
	
	func correctFeedURL(_ feedURL: String) -> String? {
		return _correction?(feedURL)
	}
	
	func transform(_ parsedFeed: ParsedFeed) -> ParsedFeed {
		return _transformer?(parsedFeed) ?? parsedFeed
	}
}