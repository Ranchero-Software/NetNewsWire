//
//  HTMLFeedFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import RSParser

private let feedURLWordsToMatch = ["feed", "xml", "rss", "atom", "json"]

final class HTMLFeedFinder {

	var feedSpecifiers: Set<FeedSpecifier> {
		return Set(feedSpecifiersDictionary.values)
	}

	private var feedSpecifiersDictionary = [String: FeedSpecifier]()

	init(parserData: ParserData) {
		let metadata = HTMLMetadataParser.htmlMetadata(with: parserData)
		var orderFound = 0

		for oneFeedLink in metadata.feedLinks {
			if let oneURLString = oneFeedLink.urlString?.normalizedURL {
				orderFound += 1
				let oneFeedSpecifier = FeedSpecifier(title: oneFeedLink.title, urlString: oneURLString, source: .HTMLHead, orderFound: orderFound)
				addFeedSpecifier(oneFeedSpecifier)
			}
		}

		let bodyLinks = HTMLLinkParser.htmlLinks(with: parserData)
		for oneBodyLink in bodyLinks {
			if linkMightBeFeed(oneBodyLink), let normalizedURL = oneBodyLink.urlString?.normalizedURL {
				orderFound += 1
				let oneFeedSpecifier = FeedSpecifier(title: oneBodyLink.text, urlString: normalizedURL, source: .HTMLLink, orderFound: orderFound)
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
		if urlStringIsDefinitelyNotFeed(urlString) {
			return false
		}

		let massagedURLString = urlString.replacingOccurrences(of: "buzzfeed", with: "_")

		for oneMatch in feedURLWordsToMatch {
			let range = (massagedURLString as NSString).range(of: oneMatch, options: .caseInsensitive)
			if range.length > 0 {
				return true
			}
		}

		return false
	}

	static let nonFeedDomains = ["x.com", "twitter.com", "facebook.com", "instagram.com"]
	static let nonFeedExtensions: Set<String> = ["html", "pdf", "jpg", "jpeg", "png", "gif", "tiff", "heic", "svg", "webp", "bmp", "ico", "zip", "tar", "tgz", "gz", "dmg", "mp3", "mp4", "mov", "mpeg", "mpg", "m4a", "aac", "wav", "aiff", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]

	func urlStringIsDefinitelyNotFeed(_ urlString: String) -> Bool {
		if SpecialCase.urlStringMatchesDomain(urlString, Self.nonFeedDomains) {
			return true
		}
		// The path’s extension, so a query or fragment doesn’t hide it.
		let pathExtension = URL(string: urlString)?.pathExtension ?? (urlString as NSString).pathExtension
		return Self.nonFeedExtensions.contains(pathExtension.lowercased())
	}

	func linkMightBeFeed(_ link: HTMLLink) -> Bool {
		if let linkURLString = link.urlString, urlStringMightBeFeed(linkURLString) {
			return true
		}
		return false
	}
}
