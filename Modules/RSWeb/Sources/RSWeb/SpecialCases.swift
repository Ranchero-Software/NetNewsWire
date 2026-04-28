//
//  SpecialCases.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/12/24.
//

import Foundation
import os

nonisolated public let localeForLowercasing = Locale(identifier: "en_US")

nonisolated public struct SpecialCase {
	public static let rachelByTheBayHostName = "rachelbythebay.com"
	public static let openRSSOrgHostName = "openrss.org"
	public static let youtubeHostName = "youtube.com"

	public static func urlStringContainSpecialCase(_ urlString: String, _ specialCases: [String]) -> Bool {
		let lowerURLString = urlString.lowercased(with: localeForLowercasing)
		for specialCase in specialCases {
			if lowerURLString.contains(specialCase) {
				return true
			}
		}
		return false
	}

	/// Returns true if the URL’s host matches one of the supplied domain names.
	///
	/// Unlike `urlStringContainSpecialCase`, this checks only the host component — not the path or query.
	/// A leading `www.` on the URL’s host is treated as optional, so `example.com` in `domains` matches a host of either `example.com` or `www.example.com`.
	/// The supplied `domains` are assumed to already be lowercased and to have any leading `www.` stripped.
	public static func urlStringMatchesDomain(_ urlString: String, _ domains: [String]) -> Bool {
		guard let url = URL(string: urlString), let host = url.host()?.lowercased(with: localeForLowercasing) else {
			return false
		}
		let normalizedHost = stringByStrippingWWWPrefix(host)
		for domain in domains {
			if normalizedHost == domain {
				return true
			}
		}
		return false
	}

	private static let wwwPrefix = "www."

	private static func stringByStrippingWWWPrefix(_ host: String) -> String {
		if host.hasPrefix(wwwPrefix) {
			return String(host.dropFirst(wwwPrefix.count))
		}
		return host
	}
}

nonisolated extension URL {

	public var isOpenRSSOrgURL: Bool {
		guard let host = host() else {
			return false
		}
		return SpecialCase.urlStringContainSpecialCase(host, [SpecialCase.openRSSOrgHostName])
	}

	public var isRachelByTheBayURL: Bool {
		guard let host = host() else {
			return false
		}
		return SpecialCase.urlStringContainSpecialCase(host, [SpecialCase.rachelByTheBayHostName])
	}

	public var isYoutubeURL: Bool {
		guard let host = host() else {
			return false
		}
		return SpecialCase.urlStringContainSpecialCase(host, [SpecialCase.youtubeHostName])
	}
}

nonisolated extension Set where Element == URL {

	func byRemovingOpenRSSOrgURLs() -> Set<URL> {
		filter { !$0.isOpenRSSOrgURL }
	}

	func openRSSOrgURLs() -> Set<URL> {
		filter { $0.isOpenRSSOrgURL }
	}

	func byRemovingAllButOneRandomOpenRSSOrgURL() -> Set<URL> {
		if self.isEmpty || self.count == 1 {
			return self
		}

		let openRSSOrgURLs = openRSSOrgURLs()
		if openRSSOrgURLs.isEmpty || openRSSOrgURLs.count == 1 {
			return self
		}

		let randomIndex = Int.random(in: 0..<openRSSOrgURLs.count)
		let singleOpenRSSOrgURLToRead = (Array(openRSSOrgURLs))[randomIndex]

		var urls = byRemovingOpenRSSOrgURLs()
		urls.insert(singleOpenRSSOrgURLToRead)

		return urls
	}
}

nonisolated extension URLRequest {

	mutating func addSpecialCaseUserAgentIfNeeded() {
		guard let url else {
			return
		}

		if url.isOpenRSSOrgURL || url.isRachelByTheBayURL {
			setValue(UserAgent.extendedUserAgent, forHTTPHeaderField: HTTPRequestHeader.userAgent)
		}
	}
}

nonisolated extension UserAgent {

	static let extendedUserAgent = {
#if os(iOS)
		let platform = "iOS"
#else
		let platform = "Mac"
#endif
		let version = stringFromInfoPlist("CFBundleShortVersionString") ?? "Unknown"
		let build = stringFromInfoPlist("CFBundleVersion") ?? "Unknown"

		let template = Bundle.main.object(forInfoDictionaryKey: "UserAgentExtended") as? String

		var userAgent = template!.replacingOccurrences(of: "[platform]", with: platform)
		userAgent = userAgent.replacingOccurrences(of: "[version]", with: version)
		userAgent = userAgent.replacingOccurrences(of: "[build]", with: build)

		return userAgent
	}()

	private static func stringFromInfoPlist(_ key: String) -> String? {
		guard let s = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
			assertionFailure("Expected to get \(key) from infoDictionary.")
			return nil
		}
		return s
	}
}
