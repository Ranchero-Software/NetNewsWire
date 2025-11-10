//
//  FeedSpecifier.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public struct FeedSpecifier: Hashable, Sendable {

	public enum Source: Int, Sendable {
		case UserEntered = 0, HTMLHead, HTMLLink

		func equalToOrBetterThan(_ otherSource: Source) -> Bool {
			return self.rawValue <= otherSource.rawValue
		}
	}

	public let title: String?
	public let urlString: String
	public let source: Source
	public let orderFound: Int
	public var score: Int {
		calculatedScore()
	}

	public init(title: String?, urlString: String, source: Source, orderFound: Int) {
		self.title = title
		self.urlString = urlString
		self.source = source
		self.orderFound = orderFound
	}
	
	/// Some feed URLs are known in advance. Save time/bandwidth by special-casing those.
	static func knownFeedSpecifier(url: URL) -> FeedSpecifier? {
		if url.isRachelByTheBayURL {
			let feedURLString = "https://rachelbythebay.com/w/atom.xml"
			return FeedSpecifier(title: "writing - rachelbythebay", urlString: feedURLString, source: .UserEntered, orderFound: 0)
		}

		return nil
	}

	func feedSpecifierByMerging(_ feedSpecifier: FeedSpecifier) -> FeedSpecifier {
		// Take the best data (non-nil title, better source) to create a new feed specifier;

		let mergedTitle = title ?? feedSpecifier.title
		let mergedSource = source.equalToOrBetterThan(feedSpecifier.source) ? source : feedSpecifier.source
		let mergedOrderFound = orderFound < feedSpecifier.orderFound ? orderFound : feedSpecifier.orderFound

		return FeedSpecifier(title: mergedTitle, urlString: urlString, source: mergedSource, orderFound: mergedOrderFound)
	}

	public static func bestFeed(in feedSpecifiers: Set<FeedSpecifier>) -> FeedSpecifier? {
		if feedSpecifiers.isEmpty {
			return nil
		}
		if feedSpecifiers.count == 1 {
			return feedSpecifiers.anyObject()
		}

		var currentHighScore = Int.min
		var currentBestFeed: FeedSpecifier? = nil

		for oneFeedSpecifier in feedSpecifiers {
			let oneScore = oneFeedSpecifier.score
			if oneScore > currentHighScore {
				currentHighScore = oneScore
				currentBestFeed = oneFeedSpecifier
			}
		}

		return currentBestFeed
	}
}

private extension FeedSpecifier {

	func calculatedScore() -> Int {
		var score = 0

		if source == .UserEntered {
			return 1000
		}
		else if source == .HTMLHead {
			score = score + 50
		}

		score = score - ((orderFound - 1) * 5)

		if urlString.caseInsensitiveContains("comments") {
			score = score - 10
		}
		if urlString.caseInsensitiveContains("podcast") {
			score = score - 10
		}
		if urlString.caseInsensitiveContains("rss") {
			score = score + 5
		}
		if urlString.hasSuffix("/index.xml") {
			score = score + 5
		}
		if urlString.hasSuffix("/feed/") {
			score = score + 5
		}
		if urlString.hasSuffix("/feed") {
			score = score + 4
		}
		if urlString.caseInsensitiveContains("json") {
			score = score + 3
		}

		if let title = title {
			if title.caseInsensitiveContains("comments") {
				score = score - 10
			}
		}

		return score
	}
}
