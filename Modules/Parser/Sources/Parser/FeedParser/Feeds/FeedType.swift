//
//  FeedType.swift
//  Parser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

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

		let count = data.count
		if count < minNumberOfBytesRequired {
			return .unknown
		}

		return data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in

			guard let baseAddress = pointer.baseAddress else {
				return .unknown
			}
			let cCharPointer = baseAddress.assumingMemoryBound(to: CChar.self)

			if isProbablyJSON(cCharPointer, count) {

				if isPartialData {
					// Might not be able to detect a JSON Feed without all data.
					// Dr. Drang’s JSON Feed (see althis.json and allthis-partial.json in tests)
					// has, at this writing, the JSON version element at the end of the feed,
					// which is totally legal — but it means not being able to detect
					// that it’s a JSON Feed without all the data.
					// So this returns .unknown instead of .notAFeed.
					return .unknown
				}

				if isProbablyJSONFeed(cCharPointer, count) {
					return .jsonFeed
				}
				if isProbablyRSSInJSON(cCharPointer, count) {
					return .rssInJSON
				}
			}

			if isProbablyRSS(cCharPointer, count) {
				return .rss
			}
			if isProbablyAtom(cCharPointer, count) {
				return .atom
			}

			return .notAFeed
		}
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

	static func isProbablyJSON(_ bytes: UnsafePointer<CChar>, _ count: Int) -> Bool {

		bytesStartWithStringIgnoringWhitespace("{", bytes, count)
	}

	static func isProbablyJSONFeed(_ bytes: UnsafePointer<CChar>, _ count: Int) -> Bool {

		// Assumes already called `isProbablyJSON` and it returned true.
		didFindString("://jsonfeed.org/version/", bytes, count) || didFindString(":\\/\\/jsonfeed.org\\/version\\/", bytes, count)
	}

	static func isProbablyRSSInJSON(_ bytes: UnsafePointer<CChar>, _ count: Int) -> Bool {

		// Assumes already called `isProbablyJSON` and it returned true.
		didFindString("rss", bytes, count) && didFindString("channel", bytes, count) && didFindString("item", bytes, count)
	}

	static func didFindString(_ string: UnsafePointer<CChar>, _ bytes: UnsafePointer<CChar>, _ numberOfBytes: Int) -> Bool {

		let foundString = strnstr(bytes, string, numberOfBytes)
		return foundString != nil
	}

	struct Whitespace {
		static let space = Character(" ").asciiValue!
		static let `return` = Character("\r").asciiValue!
		static let newline = Character("\n").asciiValue!
		static let tab = Character("\t").asciiValue!
	}

	static func bytesStartWithStringIgnoringWhitespace(_ string: UnsafePointer<CChar>, _ bytes: UnsafePointer<CChar>, _ numberOfBytes: Int) -> Bool {

		var i = 0

		while i < numberOfBytes {

			let ch = bytes[i]

			if ch == Whitespace.space || ch == Whitespace.return || ch == Whitespace.newline || ch == Whitespace.tab {
				i += 1
				continue
			}

			if ch == string[0] {
				if let found = strnstr(bytes, string, numberOfBytes) {
					return found == bytes + i
				}
			}

			// Allow for a BOM of up to four bytes (assuming BOM is only at the start)
			if i < 4 {
				i += 1
				continue
			}

			break
		}

		return false
	}
}
