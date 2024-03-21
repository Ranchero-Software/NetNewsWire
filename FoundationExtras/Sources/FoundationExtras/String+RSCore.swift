//
//  String+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 11/26/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CommonCrypto
import os

public extension String {

	func htmlByAddingLink(_ link: String, className: String? = nil) -> String {
		if let className = className {
			return "<a class=\"\(className)\" href=\"\(link)\">\(self)</a>"
		}
		return "<a href=\"\(link)\">\(self)</a>"
	}

	func htmlBySurroundingWithTag(_ tag: String) -> String {
		return "<\(tag)>\(self)</\(tag)>"
	}

	static func htmlWithLink(_ link: String) -> String {
		return link.htmlByAddingLink(link)
	}
	
    func hmacUsingSHA1(key: String) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), key, key.count, self, self.count, &digest)
        let data = Data(digest)
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
	
}

public extension String {

	/// An MD5 hash of the string's UTF-8 representation.
	var md5Hash: Data {
		self.data(using: .utf8)!.md5Hash
	}

	/// A hexadecimal representaion of an MD5 hash of the string's UTF-8 representation.
	var md5String: String {
		self.md5Hash.hexadecimalString!
	}

	/// Trims leading and trailing whitespace, and collapses other whitespace into a single space.
	var collapsingWhitespace: String {
		var dest = self
		dest = dest.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		return dest.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
	}

	/// Trims whitespace from the beginning and end of the string.
	var trimmingWhitespace: String {
		self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
	}

	/// Returns `true` if the string contains any character from a set.
	private func containsAnyCharacter(from charset: CharacterSet) -> Bool {
		return self.rangeOfCharacter(from: charset) != nil
	}

	/// Returns `true` if a string may be an IPv6 URL.
	private var mayBeIPv6URL: Bool {
		self.range(of: "\\[[0-9a-fA-F:]+\\]", options: .regularExpression) != nil
	}

	private var hostMayBeLocalhost: Bool {
		guard let components = URLComponents(string: self) else { return false }

		if let host = components.host {
			return host == "localhost"
		}

		// If self is schemeless:
		if components.path.split(separator: "/", omittingEmptySubsequences: false).first == "localhost" { return true }

		return false
	}

	/// Returns `true` if the string may be a URL.
	var mayBeURL: Bool {

		let s = self.trimmingWhitespace

		if (s.isEmpty || (!s.contains(".") && !s.mayBeIPv6URL && !s.hostMayBeLocalhost)) {
			return false
		}

		let banned = CharacterSet.whitespacesAndNewlines.union(.controlCharacters).union(.illegalCharacters)

		if s.containsAnyCharacter(from: banned) {
			return false
		}

		return true

	}

	/// Normalizes a URL that could begin with "feed:" or "feeds:", converting
	/// it to a URL beginning with "http:" or "https:"
	///
	/// Strategy:
	/// 1) Note whether or not this is a feed: or feeds: or other prefix
	/// 2) Strip the feed: or feeds: prefix
	/// 3) If the resulting string is not prefixed with http: or https:, then add http:// as a prefix
	///
	/// - Note: Must handle edge case (like boingboing.net) where the feed URL is
	/// feed:http://boingboing.net/feed
	var normalizedURL: String {

		/// Prefix constants.
		/// - Note: The lack of colon on `http(s)` is intentional.
		enum Prefix {
			static let feed = "feed:"
			static let feeds = "feeds:"
			static let http = "http"
			static let https = "https"
		}

		var s = self.trimmingWhitespace
		var wasFeeds = false

		var lowercaseS = s.lowercased()

		if lowercaseS.hasPrefix(Prefix.feeds) {
			wasFeeds = true
			s = s.stripping(prefix: Prefix.feeds)
		} else if lowercaseS.hasPrefix(Prefix.feed) {
			s = s.stripping(prefix: Prefix.feed)
		}

		if s.hasPrefix("//") {
			s = s.stripping(prefix: "//")
		}

		lowercaseS = s.lowercased()
		if !lowercaseS.hasPrefix(Prefix.http) {
			s = "\(wasFeeds ? Prefix.https : Prefix.http)://\(s)"
		}

		// Handle top-level URLs missing a trailing slash, as in https://ranchero.com — make it http://ranchero.com/
		// We’re sticklers for this kind of thing.
		// History: it used to be that on Windows they were always fine with no trailing slash,
		// and on Macs the trailing slash would appear. In recent years you’ve seen no trailing slash
		// on Macs too, but we’re bucking that trend. We’re Mac people, doggone it. Keepers of the flame.
		// Add the slash.
		let componentsCount = s.components(separatedBy: "/").count
		if componentsCount == 3 {
			s = s.appending("/")
		}

		return s
	}

	/// Removes a prefix from the beginning of a string.
	/// - Parameters:
	///   - prefix: The prefix to remove
	///   - caseSensitive: `true` if the prefix should be matched case-sensitively.
	/// - Returns: A new string with the prefix removed.
	func stripping(prefix: String, caseSensitive: Bool = false) -> String {
		let options: String.CompareOptions = caseSensitive ? .anchored : [.anchored, .caseInsensitive]

		if let range = self.range(of: prefix, options: options) {
			return self.replacingCharacters(in: range, with: "")
		}

		return self
	}

	/// Removes a suffix from the end of a string.
	/// - Parameters:
	///   - suffix: The suffix to remove
	///   - caseSensitive: `true` if the suffix should be matched case-sensitively.
	/// - Returns: A new string with the suffix removed.
	func stripping(suffix: String, caseSensitive: Bool = false) -> String {
		let options: String.CompareOptions = caseSensitive ? [.backwards, .anchored] : [.backwards, .anchored, .caseInsensitive]

		if let range = self.range(of: suffix, options: options) {
			return self.replacingCharacters(in: range, with: "")
		}

		return self;
	}

	/// Removes an HTML tag and everything between its start and end tags.
	///
	/// - Parameter tag: The tag to remove.
	///
	/// - Returns: A new copy of `self` with the tag removed.
	///
	/// - Note: Doesn't work correctly with nested tags of the same name.
	private func removingTagAndContents(_ tag: String) -> String {
		return self.replacingOccurrences(of: "<\(tag).+?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
	}

	/// Strips HTML from a string.
	/// - Parameter maxCharacters: The maximum characters in the return string.
	///	If `nil`, the whole string is used.
	func strippingHTML(maxCharacters: Int? = nil) -> String {
		if !self.contains("<") {

			if let maxCharacters = maxCharacters, maxCharacters < count {
				let ix = self.index(self.startIndex, offsetBy: maxCharacters)
				return String(self[..<ix])
			}

			return self
		}

		var preflight = self

		// NOTE: If performance on repeated invocations becomes an issue here, the regexes can be cached.
		let options: String.CompareOptions = [.regularExpression, .caseInsensitive]
		preflight = preflight.replacingOccurrences(of: "</?(?:blockquote|p|div)>", with: " ", options: options)
		preflight = preflight.replacingOccurrences(of: "<p>|</?div>|<br(?: ?/)?>|</li>", with: "\n", options: options)
		preflight = preflight.removingTagAndContents("script")
		preflight = preflight.removingTagAndContents("style")

		var s = String()
		s.reserveCapacity(preflight.count)
		var lastCharacterWasSpace = false
		var charactersAdded = 0
		var level = 0

		for var char in preflight {
			if char == "<" {
				level += 1
			} else if char == ">" {
				level -= 1
			} else if level == 0 {

				if char == " " || char == "\r" || char == "\t" || char == "\n" {
					if lastCharacterWasSpace {
						continue
					} else {
						lastCharacterWasSpace = true
					}
					char = " "
				} else {
					lastCharacterWasSpace = false
				}

				s.append(char)

				if let maxCharacters = maxCharacters {
					charactersAdded += 1
					if (charactersAdded >= maxCharacters) {
						break
					}
				}
			}
		}

		return s
	}

	/// A copy of an HTML string converted to plain text.
	///
	/// Replaces `p`, `blockquote`, `div`, `br`, and `li` tags with varying quantities
	/// of newlines, strips all other tags, and guarantees no more than two consecutive newlines.
	///
	/// - Returns: A copy of self, with HTML tags removed..
	func convertingToPlainText() -> String {
		if !self.contains("<") {
			return self
		}

		var preflight = self

		// NOTE: If performance on repeated invocations becomes an issue here, the regexes can be cached.
		let options: String.CompareOptions = [.regularExpression, .caseInsensitive]
		preflight = preflight.replacingOccurrences(of: "</?blockquote>|</p>", with: "\n\n", options: options)
		preflight = preflight.replacingOccurrences(of: "<p>|</?div>|<br(?: ?/)?>|</li>", with: "\n", options: options)

		var s = String()
		s.reserveCapacity(preflight.count)
		var level = 0

		for char in preflight {
			if char == "<" {
				level += 1
			} else if char == ">" {
				level -= 1
			} else if level == 0 {
				s.append(char)
			}
		}

		return s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
	}


	/// Returns a Boolean value indicating whether the string contains another string, case-insensitively.
	///
	/// - Parameter string: The string to search for.
	///
	/// - Returns: `true` if the string contains `string`; `false` otherswise.
	func caseInsensitiveContains(_ string: String) -> Bool {
		return self.range(of: string, options: .caseInsensitive) != nil
	}

	/// Returns the string with the special XML characters (other than single-quote) ampersand-escaped.
	///
	/// The four escaped characters are `<`, `>`, `&`, and `"`.
	var escapingSpecialXMLCharacters: String {
		var escaped = String()

		for char in self {
			switch char {
				case "&":
					escaped.append("&amp;")
				case "<":
					escaped.append("&lt;")
				case ">":
					escaped.append("&gt;")
				case "\"":
					escaped.append("&quot;")
				default:
					escaped.append(char)
			}
		}

		return escaped
	}

	/// Initializes a string with a run of tabs.
	///
	/// - Parameter tabCount: The number of tabs in the returned string. Must be greater than or equal to zero.
	init(tabCount: Int) {
		self = String(repeating: "\t", count: tabCount)
	}

	/// Prepends tabs to a string.
	///
	/// - Parameter tabCount: The number of tabs to prepend. Must be greater than or equal to zero.
	///
	/// - Returns: The string with `numberOfTabs` tabs prepended.
	func prepending(tabCount: Int) -> String {

		let tabs = String(tabCount: tabCount)
		return "\(tabs)\(self)"
	}

	/// Returns the string with `http://` or `https://` removed from the beginning.
	var strippingHTTPOrHTTPSScheme: String {
		self.stripping(prefix: "http://").stripping(prefix: "https://")
	}

}
