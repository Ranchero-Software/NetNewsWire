//
//  HTMLFeedFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser

private let feedURLWordsToMatch = ["feed", "xml", "rss", "atom", "json"]

class HTMLFeedFinder {

	var feedSpecifiers: Set<FeedSpecifier> {
		return Set(feedSpecifiersDictionary.values)
	}

	private var feedSpecifiersDictionary = [String: FeedSpecifier]()

	init(parserData: ParserData) {
		let metadata = HTMLMetadataParser.metadata(with: parserData)
		var orderFound = 0

		if let feedLinks = metadata.feedLinks {
			for oneFeedLink in feedLinks {
				if let oneURLString = oneFeedLink.urlString?.normalizedURL {
					orderFound += 1
					let oneFeedSpecifier = FeedSpecifier(title: oneFeedLink.title, urlString: oneURLString, source: .htmlHead, orderFound: orderFound)
					addFeedSpecifier(oneFeedSpecifier)
				}
			}
		}

		let bodyLinks = HTMLLinkParser.htmlLinks(with: parserData)
		for oneBodyLink in bodyLinks {
			if linkMightBeFeed(oneBodyLink), let normalizedURL = oneBodyLink.urlString?.normalizedURL {
				orderFound += 1
				let oneFeedSpecifier = FeedSpecifier(title: oneBodyLink.text, urlString: normalizedURL, source: .htmlLink, orderFound: orderFound)
				addFeedSpecifier(oneFeedSpecifier)
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
		} else {
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

	func linkMightBeFeed(_ link: HTMLLink) -> Bool {
		if let linkURLString = link.urlString, urlStringMightBeFeed(linkURLString) {
			return true
		}
		return false
	}
}
