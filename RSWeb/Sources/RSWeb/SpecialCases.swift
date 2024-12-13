//
//  SpecialCases.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/12/24.
//

import Foundation
import os

extension URL {

	private static let openRSSOrgURLCache = OSAllocatedUnfairLock(initialState: [URL: Bool]())

	public var isOpenRSSOrgURL: Bool {

		Self.openRSSOrgURLCache.withLock { cache in
			if let cachedResult = cache[self] {
				return cachedResult
			}

			let result: Bool
			if let host = host(), host.contains("openrss.org") {
				result = true
			}
			else {
				result = false
			}

			cache[self] = result
			return result
		}
	}
}

extension Set where Element == URL {

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

extension UserAgent {

	static let openRSSOrgUserAgent = {

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
