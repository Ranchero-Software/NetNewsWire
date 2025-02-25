//
//  FeedSpecifier.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedSpecifier: Hashable {

	enum Source: Int {
		case userEntered = 0, htmlHead, htmlLink

		func equalToOrBetterThan(_ otherSource: Source) -> Bool {
			return self.rawValue <= otherSource.rawValue
		}
	}

	public let title: String?
	public let urlString: String
	public let source: Source
	public let orderFound: Int
	public var score: Int {
		return calculatedScore()
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
		var currentBestFeed: FeedSpecifier?

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

		if source == .userEntered {
			return 1000
		} else if source == .htmlHead {
			score += 50
		}

		score -= (orderFound - 1) * 5

		if urlString.caseInsensitiveContains("comments") {
			score -= 10
		}
		if urlString.caseInsensitiveContains("podcast") {
			score -= 10
		}
		if urlString.caseInsensitiveContains("rss") {
			score += 5
		}
		if urlString.hasSuffix("/feed/") {
			score += 5
		}
		if urlString.hasSuffix("/feed") {
			score += 4
		}
		if urlString.caseInsensitiveContains("json") {
			score += 6
		}

		if let title = title {
			if title.caseInsensitiveContains("comments") {
				score -= 10
			}
			if title.caseInsensitiveContains("json") {
				score += 1
			}
		}

		return score
	}
}
