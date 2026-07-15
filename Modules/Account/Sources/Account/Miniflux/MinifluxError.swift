//
//  MinifluxError.swift
//  Account
//
//  Created by Dave Marquard on 7/7/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Miniflux error responses look like: {"error_message": "This feed already exists (feed_id: 123)"}
struct MinifluxErrorResponse: Decodable, Sendable {
	let errorMessage: String

	enum CodingKeys: String, CodingKey {
		case errorMessage = "error_message"
	}
}

enum MinifluxError: LocalizedError {

	case serverVersionTooOld(foundVersion: String?)
	case serverError(message: String)

	var errorDescription: String? {
		switch self {
		case .serverVersionTooOld(let foundVersion):
			guard let foundVersion else {
				return NSLocalizedString("NetNewsWire requires Miniflux 2.0.49 or later.", comment: "Server version too old")
			}
			let localizedText = NSLocalizedString("This Miniflux server is version %@, but NetNewsWire requires Miniflux 2.0.49 or later.", comment: "Server version too old")
			return NSString.localizedStringWithFormat(localizedText as NSString, foundVersion) as String
		case .serverError(let message):
			let localizedText = NSLocalizedString("The Miniflux server reported an error: %@", comment: "Server error")
			return NSString.localizedStringWithFormat(localizedText as NSString, message) as String
		}
	}
}
