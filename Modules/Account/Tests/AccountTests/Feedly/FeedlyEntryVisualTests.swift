//
//  FeedlyEntryVisualTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Testing
@testable import Account

struct FeedlyEntryVisualTests {

	@Test func visualIsImageURL() {
		// From feedly_macintosh_initial.json.
		let url = "https://cdn.vox-cdn.com/thumbor/BkK9uk46u1ujrjGO0Jav3PCQ3g0=/0x225:5363x3800/1310x873/cdn.vox-cdn.com/uploads/chorus_image/image/59608177/PIA22227_full.0.jpg"
		#expect(FeedlyEntryParser(entry: makeEntry(visualURL: url)).parsedItemRepresentation?.imageURL == url)
		#expect(FeedlyEntryParser(entry: makeEntry(visualURL: "none")).parsedItemRepresentation?.imageURL == nil)
	}
}

private extension FeedlyEntryVisualTests {

	func makeEntry(visualURL: String) -> FeedlyEntry {
		let origin = FeedlyOrigin(title: "The Verge", streamID: "feed/http://www.theverge.com/rss/full.xml", htmlURL: nil)
		return FeedlyEntry(id: "entry", title: nil, content: nil, summary: nil, author: nil, crawled: .distantPast, recrawled: nil, published: nil, origin: origin, canonical: nil, alternate: nil, unread: true, tags: nil, categories: nil, enclosure: nil, visual: FeedlyVisual(url: visualURL))
	}
}
