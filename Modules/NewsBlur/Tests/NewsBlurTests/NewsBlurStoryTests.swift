//
//  NewsBlurStoryTests.swift
//  NewsBlurTests
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Testing
@testable import NewsBlur

struct NewsBlurStoryTests {

	@Test func firstImageIsChosen() throws {
		let json = """
		{
			"story_hash": "6:a1b2c3",
			"story_feed_id": 6,
			"story_timestamp": "1761235200",
			"image_urls": [
				"http://example.com/first.jpg",
				"http://example.com/second.jpg",
				"http://example.com/third.jpg"
			],
			"secure_image_urls": {
				"http://example.com/third.jpg": "https://imageproxy.newsblur.com/third",
				"http://example.com/second.jpg": "https://imageproxy.newsblur.com/second",
				"http://example.com/first.jpg": "https://imageproxy.newsblur.com/first"
			},
			"secure_image_thumbnails": {
				"http://example.com/third.jpg": "https://imageproxy.newsblur.com/192/third",
				"http://example.com/second.jpg": "https://imageproxy.newsblur.com/192/second",
				"http://example.com/first.jpg": "https://imageproxy.newsblur.com/192/first"
			}
		}
		"""
		let story = try JSONDecoder().decode(NewsBlurStory.self, from: Data(json.utf8))

		#expect(story.imageURL == "https://imageproxy.newsblur.com/first")
		#expect(story.thumbnailURL == "https://imageproxy.newsblur.com/192/first")
	}
}
