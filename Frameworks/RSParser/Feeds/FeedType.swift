//
//  FeedType.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum FeedType {
	case rss
	case atom
	case jsonFeed
	case rssInJSON
	case unknown
	case notAFeed
}


private let minNumberOfBytesRequired = 128

public func feedType(_ parserData: ParserData) -> FeedType {

	// Can call with partial data — while still downloading, for instance.
	// If there’s not enough data, return .unknown. Ask again when there’s more data.
	// If it’s definitely not a feed, return .notAFeed.
	//
	// This is fast enough to call on the main thread.

	if parserData.data.count < minNumberOfBytesRequired {
		return .unknown
	}

	let nsdata = parserData.data as NSData
	if nsdata.isProbablyJSONFeed() {
		return .jsonFeed
	}
	if nsdata.isProbablyRSSInJSON() {
		return .rssInJSON
	}

	if nsdata.isProbablyHTML() {
		return .notAFeed
	}

	if nsdata.isProbablyRSS() {
		return .rss
	}
	if nsdata.isProbablyAtom() {
		return .atom
	}

	return .notAFeed
}
