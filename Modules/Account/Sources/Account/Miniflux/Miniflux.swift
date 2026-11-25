//
//  Miniflux.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore

public struct Miniflux {
	// Convention with this logger is to put "Miniflux: " at the beginning of each message.
	static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NetNewsWire", category: "Miniflux")

	/// Turns what the user typed into a Miniflux base URL: adds `https://` if there’s no scheme, and drops trailing slashes and a trailing `/v1`. Returns nil if there’s no host.
	public static func normalizedEndpointURL(from string: String) -> URL? {
		var text = string.trimmingWhitespace
		guard !text.isEmpty else {
			return nil
		}
		if !text.contains("://") {
			text = "https://" + text
		}

		while text.hasSuffix("/") {
			text.removeLast()
		}
		if text.hasSuffix("/v1") {
			text.removeLast(3)
		}
		while text.hasSuffix("/") {
			text.removeLast()
		}

		guard let url = URL(string: text), let host = url.host, !host.isEmpty else {
			return nil
		}
		return url
	}
}
