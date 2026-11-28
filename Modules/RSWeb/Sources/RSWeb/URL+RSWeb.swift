//
//  NSURL+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

private struct URLConstants {
	static let schemeHTTP = "http"
	static let schemeHTTPS = "https"
	static let schemeMailto = "mailto"
	static let prefixHTTP = "http://"
	static let prefixHTTPS = "https://"
	static let schemeNetNewsWire = "netnewswire"
	static let schemeFeed = "feed"
	static let schemeFeeds = "feeds"
	static let refusedSchemesForExternalApplications: Set<String> = [schemeHTTP, schemeHTTPS, schemeMailto, "tel", "javascript", "data", "file", "about", "blob", "vbscript"]
#if os(macOS)
	static let schemeMagnet = "magnet"
	static let schemeNetNewsWireFeed = "x-netnewswire-feed"
	static let allowedSchemesForOpening: Set<String> = [schemeHTTP, schemeHTTPS, schemeMailto, schemeMagnet, schemeNetNewsWire, schemeFeed, schemeFeeds, schemeNetNewsWireFeed]
#else
	static let allowedSchemesForOpening: Set<String> = [schemeHTTP, schemeHTTPS, schemeMailto, schemeNetNewsWire, schemeFeed, schemeFeeds]
#endif
}

public extension URL {

	func isHTTPSURL() -> Bool {
		return self.scheme?.lowercased(with: localeForLowercasing) == URLConstants.schemeHTTPS
	}

	func isHTTPURL() -> Bool {
		return self.scheme?.lowercased(with: localeForLowercasing) == URLConstants.schemeHTTP
	}

	func isHTTPOrHTTPSURL() -> Bool {
		return self.isHTTPSURL() || self.isHTTPURL()
	}

	func absoluteStringWithHTTPOrHTTPSPrefixRemoved() -> String? {
		// Case-inensitive. Turns http://example.com/foo into example.com/foo

		if isHTTPSURL() {
			return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTPS)
		} else if isHTTPURL() {
			return absoluteString.stringByRemovingCaseInsensitivePrefix(URLConstants.prefixHTTP)
		}

		return nil
	}

	func appendingQueryItem(_ queryItem: URLQueryItem) -> URL? {
		appendingQueryItems([queryItem])
	}

	func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL? {
		guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
			return nil
		}

		var newQueryItems = components.queryItems ?? []
		newQueryItems.append(contentsOf: queryItems)
		components.queryItems = newQueryItems

		return components.url
	}

	// Written with the help of an LLM.
	func preparedForOpeningInExternalApplication(excluding excludedSchemes: Set<String> = []) -> URL? {
		guard let scheme = scheme?.lowercased(with: localeForLowercasing),
			  !scheme.isEmpty,
			  !URLConstants.refusedSchemesForExternalApplications.contains(scheme),
			  !excludedSchemes.contains(where: { $0.lowercased(with: localeForLowercasing) == scheme }) else {
			return nil
		}

		return self
	}

	func preparedForOpeningInBrowser() -> URL? {
		guard let scheme = scheme?.lowercased(with: localeForLowercasing),
			  URLConstants.allowedSchemesForOpening.contains(scheme) else {
			return nil
		}

		var urlString = absoluteString.replacingOccurrences(of: " ", with: "%20")
		urlString = urlString.replacingOccurrences(of: "^", with: "%5E")
		urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
		urlString = urlString.replacingOccurrences(of: "&#38;", with: "&")

		return URL(string: urlString)
	}
}

private extension String {

	func stringByRemovingCaseInsensitivePrefix(_ prefix: String) -> String {
		// Returns self if it doesn’t have the given prefix.

		let lowerPrefix = prefix.lowercased()
		let lowerSelf = self.lowercased()

		if lowerSelf == lowerPrefix {
			return ""
		}
		if !lowerSelf.hasPrefix(lowerPrefix) {
			return self
		}

		let index = self.index(self.startIndex, offsetBy: prefix.count)
		return String(self[..<index])
	}
}
