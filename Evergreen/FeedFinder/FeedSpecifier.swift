//
//  FeedSpecifier.swift
//  FeedFinder
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedSpecifier: Hashable {

	public enum Source: Int {

		case UserEntered = 0, HTMLHead, HTMLLink

		func equalToOrBetterThan(_ otherSource: Source) -> Bool {

			return self.rawValue <= otherSource.rawValue
		}
	}

	public let title: String?
	public let urlString: String
	public let source: Source
	public let hashValue: Int
	public var score: Int {
		return calculatedScore()
	}
	
	init(title: String?, urlString: String, source: Source) {

		self.title = title
		self.urlString = urlString
		self.source = source
		self.hashValue = urlString.hashValue
	}

	public static func ==(lhs: FeedSpecifier, rhs: FeedSpecifier) -> Bool {

		return lhs.urlString == rhs.urlString && lhs.title == rhs.title && lhs.source == rhs.source
	}

	func feedSpecifierByMerging(_ feedSpecifier: FeedSpecifier) -> FeedSpecifier {

		// Take the best data (non-nil title, better source) to create a new feed specifier;

		let mergedTitle = title ?? feedSpecifier.title
		let mergedSource = source.equalToOrBetterThan(feedSpecifier.source) ? source : feedSpecifier.source

		return FeedSpecifier(title: mergedTitle, urlString: urlString, source: mergedSource)
	}
	
	public static func bestFeed(in feedSpecifiers: Set<FeedSpecifier>) -> FeedSpecifier? {
		
		if feedSpecifiers.isEmpty {
			return nil
		}
		if feedSpecifiers.count == 1 {
			return feedSpecifiers.anyObject()
		}
		
		var currentHighScore = 0
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
		
		if urlString.rs_caseInsensitiveContains("comments") {
			score = score - 10
		}
		if urlString.rs_caseInsensitiveContains("rss") {
			score = score + 5
		}
		if urlString.hasSuffix("/feed/") {
			score = score + 5
		}
		if urlString.hasSuffix("/feed") {
			score = score + 4
		}
		if urlString.rs_caseInsensitiveContains("json") {
			score = score + 6
		}
		
		if let title = title {
			if title.rs_caseInsensitiveContains("comments") {
				score = score - 10
			}
			if title.rs_caseInsensitiveContains("json") {
				score = score + 1
			}
		}
		
		return score
	}
}
