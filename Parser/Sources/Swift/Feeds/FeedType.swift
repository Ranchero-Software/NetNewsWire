//
//  FeedType.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
#if SWIFT_PACKAGE
import ParserObjC
#endif

public enum FeedType: Sendable {
	case rss
	case atom
	case jsonFeed
	case rssInJSON
	case unknown
	case notAFeed
}


private let minNumberOfBytesRequired = 128

public func feedType(_ parserData: ParserData, isPartialData: Bool = false) -> FeedType {

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
	if nsdata.isProbablyRSS() {
		return .rss
	}
	if nsdata.isProbablyAtom() {
		return .atom
	}

	if isPartialData && nsdata.isProbablyJSON() {
		// Might not be able to detect a JSON Feed without all data.
		// Dr. Drang’s JSON Feed (see althis.json and allthis-partial.json in tests)
		// has, at this writing, the JSON version element at the end of the feed,
		// which is totally legal — but it means not being able to detect
		// that it’s a JSON Feed without all the data.
		// So this returns .unknown instead of .notAFeed.
		return .unknown
	}

	return .notAFeed
}
