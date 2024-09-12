//
//  FeedType.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SAX

public enum FeedType: Sendable {

	case rss
	case atom
	case jsonFeed
	case rssInJSON
	case unknown
	case notAFeed

	private static let minNumberOfBytesRequired = 128

	static func feedType(_ data: Data, isPartialData: Bool = false) -> FeedType {

		// Can call with partial data — while still downloading, for instance.
		// If there’s not enough data, return .unknown. Ask again when there’s more data.
		// If it’s definitely not a feed, return .notAFeed.

		if data.count < minNumberOfBytesRequired {
			return .unknown
		}

		let count = data.count

		return data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in

			guard let baseAddress = pointer.baseAddress else {
				return .unknown
			}
			let cCharPointer = baseAddress.assumingMemoryBound(to: CChar.self)
			
			if isProbablyRSS(cCharPointer, count) {
				return .rss
			}
			if isProbablyAtom(cCharPointer, count) {
				return .atom
			}

			return .unknown
		}
//		if d.isProbablyJSONFeed() {
//			return .jsonFeed
//		}
//		if d.isProbablyRSSInJSON() {
//			return .rssInJSON
//		}
//		if d.isProbablyAtom() {
//			return .atom
//		}
//
//		if isPartialData && d.isProbablyJSON() {
//			// Might not be able to detect a JSON Feed without all data.
//			// Dr. Drang’s JSON Feed (see althis.json and allthis-partial.json in tests)
//			// has, at this writing, the JSON version element at the end of the feed,
//			// which is totally legal — but it means not being able to detect
//			// that it’s a JSON Feed without all the data.
//			// So this returns .unknown instead of .notAFeed.
//			return .unknown
//		}

//		return .notAFeed

//		return type
	}
}

private extension FeedType {

	static func isProbablyRSS(_ bytes: UnsafePointer<CChar>, _ count: Int) -> Bool {

		if didFindString("<rss", bytes, count) || didFindString("<rdf:RDF", bytes, count) {
			return true
		}

		return didFindString("<channel>", bytes, count) && didFindString("<pubDate>", bytes, count)
	}

	static func isProbablyAtom(_ bytes: UnsafePointer<CChar>, _ count: Int) -> Bool {

		didFindString("<feed", bytes, count)
	}

	static func didFindString(_ string: UnsafePointer<CChar>, _ bytes: UnsafePointer<CChar>, _ numberOfBytes: Int) -> Bool {

		let foundString = strnstr(bytes, string, numberOfBytes)
		return foundString != nil
	}
}
