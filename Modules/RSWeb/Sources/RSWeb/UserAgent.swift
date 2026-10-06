//
//  UserAgent.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Which User-Agent a download sends.
public enum UserAgentStyle: Sendable {

	/// The app's normal feed-reader user agent — the session default.
	case feed

	/// The extended feed-reader user agent that some hosts require.
	case specialCaseFeed

	/// The browser-style user agent that matches the article web view.
	case browser
}

nonisolated public struct UserAgent {

	/// Browser-style user agent for favicon and homepage-HTML downloads —
	/// some servers reject requests without a browser-like user agent.
	/// The app replaces this at startup with the article web view's actual
	/// user agent, so the two match. This value is the fallback.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/4868>
	@MainActor public static var browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) NetNewsWire"

	public static func fromInfoPlist() -> String? {

		return Bundle.main.object(forInfoDictionaryKey: "UserAgent") as? String
	}

	public static func headers() -> [AnyHashable: String]? {

		guard let userAgent = fromInfoPlist() else {
			return nil
		}

		return [HTTPRequestHeader.userAgent: userAgent]
	}
}
