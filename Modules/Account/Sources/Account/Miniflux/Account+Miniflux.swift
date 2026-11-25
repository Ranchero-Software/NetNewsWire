//
//  Account+Miniflux.swift
//  Account
//
//  Created by Brent Simmons on 11/25/26.
//

import Foundation
import RSCore

public extension Account {

	/// Turns what the user typed into a Miniflux base URL: adds `https://` if there’s no scheme, and drops trailing slashes and a trailing `/v1`. Returns nil if there’s no host.
	static func normalizedMinifluxEndpointURL(from string: String) -> URL? {
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
