//
//  FeedbinEntryTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Testing
@testable import Account

struct FeedbinEntryTests {

	@Test func imagesAndEnclosure() throws {
		// Fields from the Feedbin API docs for mode=extended.
		let json = """
		{
			"id": 2077,
			"feed_id": 135,
			"title": "Objective-C Runtime Releases",
			"url": "http://mjtsai.com/blog/2013/02/02/objective-c-runtime-releases/",
			"author": "Michael Tsai",
			"content": "<p>Bavarious created a GitHub repository.</p>",
			"summary": "Bavarious created a GitHub repository.",
			"published": "2013-02-03T01:00:19.000000Z",
			"created_at": "2013-02-04T01:00:19.127893Z",
			"images": {
				"original_url": "http://example.com/image.jpg",
				"size_1": {
					"cdn_url": "https://images.feedbinusercontent.com/image.jpg",
					"width": 542,
					"height": 304
				}
			},
			"enclosure": {
				"enclosure_url": "http://example.com/episode.mp3",
				"enclosure_type": "audio/mpeg",
				"enclosure_length": "54947132",
				"itunes_duration": "01:54:09",
				"itunes_image": "http://example.com/artwork.jpg"
			}
		}
		"""
		let entry = try JSONDecoder().decode(FeedbinEntry.self, from: Data(json.utf8))

		#expect(entry.imageURL == "http://example.com/image.jpg")
		#expect(entry.thumbnailURL == "https://images.feedbinusercontent.com/image.jpg")

		let attachment = try #require(entry.attachments?.first)
		#expect(attachment.url == "http://example.com/episode.mp3")
		#expect(attachment.mimeType == "audio/mpeg")
		#expect(attachment.sizeInBytes == 54947132)
		#expect(attachment.durationInSeconds == 6849)
	}
}
