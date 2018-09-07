//
//  HTMLFeedFinder.swift
//  FeedFinder
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser

private let feedURLWordsToMatch = ["feed", "xml", "rss", "atom", "json"]

class HTMLFeedFinder {
	
	var feedSpecifiers: Set<FeedSpecifier> {
		return Set(feedSpecifiersDictionary.values)
	}
	
	fileprivate var feedSpecifiersDictionary = [String: FeedSpecifier]()
	
	init(parserData: ParserData) {
		
		let metadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)

		for oneFeedLink in metadata.feedLinks {
			if let oneURLString = oneFeedLink.urlString {
				let oneFeedSpecifier = FeedSpecifier(title: oneFeedLink.title, urlString: oneURLString, source: .HTMLHead)
				addFeedSpecifier(oneFeedSpecifier)
			}
		}

		if let bodyLinks = RSHTMLLinkParser.htmlLinks(with: parserData) {
			for oneBodyLink in bodyLinks {

				if linkMightBeFeed(oneBodyLink) {
					let normalizedURL = oneBodyLink.urlString.rs_normalizedURL()
					let oneFeedSpecifier = FeedSpecifier(title: oneBodyLink.text, urlString: normalizedURL, source: .HTMLLink)
					addFeedSpecifier(oneFeedSpecifier)
				}
			}
		}
	}
}

private extension HTMLFeedFinder {

	func addFeedSpecifier(_ feedSpecifier: FeedSpecifier) {

		// If there’s an existing feed specifier, merge the two so that we have the best data. If one has a title and one doesn’t, use that non-nil title. Use the better source.

		if let existingFeedSpecifier = feedSpecifiersDictionary[feedSpecifier.urlString] {
			let mergedFeedSpecifier = existingFeedSpecifier.feedSpecifierByMerging(feedSpecifier)
			feedSpecifiersDictionary[feedSpecifier.urlString] = mergedFeedSpecifier
		}
		else {
			feedSpecifiersDictionary[feedSpecifier.urlString] = feedSpecifier
		}
	}

	func urlStringMightBeFeed(_ urlString: String) -> Bool {

		let massagedURLString = urlString.replacingOccurrences(of: "buzzfeed", with: "_")

		for oneMatch in feedURLWordsToMatch {
			let range = (massagedURLString as NSString).range(of: oneMatch, options: .caseInsensitive)
			if range.length > 0 {
				return true
			}
		}

		return false
	}

	func linkMightBeFeed(_ link: RSHTMLLink) -> Bool {

		if let linkURLString = link.urlString, urlStringMightBeFeed(linkURLString) {
			return true
		}
		return false
	}
}
