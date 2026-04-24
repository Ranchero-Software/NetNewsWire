//
//  String+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 11/26/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CommonCrypto
import CryptoKit

private let hexDigits: [UInt8] = Array("0123456789abcdef".utf8)

public extension String {

	func htmlByAddingLink(_ link: String, className: String? = nil) -> String {
		if let className = className {
			return "<a class=\"\(className)\" href=\"\(link)\">\(self)</a>"
		}
		return "<a href=\"\(link)\">\(self)</a>"
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

	/// MD5 hash of the string's UTF-8 bytes, formatted as 32 lowercase hex characters.
	/// Defined for the empty string — MD5("") is "d41d8cd98f00b204e9800998ecf8427e".
	var md5String: String {
		let digest = Insecure.MD5.hash(data: Data(utf8))
		// Build the 32-byte hex buffer directly from the 16 digest bytes — no per-byte
		// String allocations, no printf format-string parsing.
		var hex = [UInt8](repeating: 0, count: 32)
		var i = 0
		for byte in digest {
			hex[i]     = hexDigits[Int(byte >> 4)]
			hex[i + 1] = hexDigits[Int(byte & 0x0F)]
			i += 2
		}
		return String(decoding: hex, as: UTF8.self)
	}

	/// Trims leading and trailing whitespace and collapses other whitespace into a single space.
	///
	/// The original version used `trimmingCharacters` and `replacingOccurrences`
	/// with regex: `"\\s+"`
	///
	/// This faster version loops through UTF-8 bytes. Handles the six
	/// ASCII whitespace characters matched by NSRegularExpression's `\s`
	/// (space, tab, LF, VT, FF, CR). Non-ASCII bytes pass through unchanged —
	/// same as the regex version.
	var collapsingWhitespace: String {
		let spaceByte = UInt8(ascii: " ")
		let tabByte = UInt8(ascii: "\t")
		let crByte = UInt8(ascii: "\r")

		let utf8 = self.utf8
		var out = [UInt8]()
		out.reserveCapacity(utf8.count)

		var sawNonSpace = false
		var pendingSpace = false

		for byte in utf8 {
			if byte == spaceByte || (byte >= tabByte && byte <= crByte) {
				// Is whitespace. Emit at most one space —
				// and only after we've seen a non-space (skips
				// leading whitespace).
				if sawNonSpace {
					pendingSpace = true
				}
				continue
			}
			if pendingSpace {
				out.append(spaceByte)
				pendingSpace = false
			}
			sawNonSpace = true
			out.append(byte)
		}
		// Trailing `pendingSpace` is discarded — that's the "trim
		// trailing whitespace" half of the behavior.

		return String(decoding: out, as: UTF8.self)
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

		if s.isEmpty || (!s.contains(".") && !s.mayBeIPv6URL && !s.hostMayBeLocalhost) {
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

		return self
	}

	/// A copy of an HTML string converted to plain text.
	///
	/// Replaces `p`, `blockquote`, `div`, `br`, and `li` tags with varying quantities
	/// of newlines, strips all other tags, and guarantees no more than two consecutive newlines.
	///
	/// - Returns: A copy of self, with HTML tags removed.
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
	/// - Returns: `true` if the string contains `string`; `false` otherwise.
	func caseInsensitiveContains(_ string: String) -> Bool {
		self.range(of: string, options: .caseInsensitive) != nil
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

	/// Prepends tabs to a string.
	///
	/// - Parameter tabCount: The number of tabs to prepend. Must be greater than or equal to zero.
	///
	/// - Returns: The string with `numberOfTabs` tabs prepended.
	func prepending(tabCount: Int) -> String {
		let tabs = String(repeating: "\t", count: tabCount)
		return "\(tabs)\(self)"
	}

	/// Returns the string with `http://` or `https://` removed from the beginning.
	var strippingHTTPOrHTTPSScheme: String {
		self.stripping(prefix: "http://").stripping(prefix: "https://")
	}
}
