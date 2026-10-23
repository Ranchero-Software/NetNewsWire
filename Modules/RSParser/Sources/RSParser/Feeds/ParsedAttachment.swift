//
//  ParsedAttachment.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedAttachment: Hashable, Sendable {

	/// Media RSS `medium` attribute.
	public enum Medium: String, Sendable {
		case image
		case audio
		case video
		case document
		case executable
	}

	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?
	public let width: Int?
	public let height: Int?
	public let medium: Medium?

	public init?(url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?, width: Int?, height: Int?, medium: Medium?) {
		if url.isEmpty {
			return nil
		}

		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds
		self.width = width
		self.height = height
		self.medium = medium
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}
}

// MARK: - Merging

extension ParsedAttachment {

	/// Copy with each nil property filled in from `other`.
	func filledIn(from other: ParsedAttachment) -> ParsedAttachment {
		ParsedAttachment(url: url, mimeType: mimeType ?? other.mimeType, title: title ?? other.title, sizeInBytes: sizeInBytes ?? other.sizeInBytes, durationInSeconds: durationInSeconds ?? other.durationInSeconds, width: width ?? other.width, height: height ?? other.height, medium: medium ?? other.medium) ?? self
	}

	func withDurationInSeconds(_ durationInSeconds: Int) -> ParsedAttachment {
		ParsedAttachment(url: url, mimeType: mimeType, title: title, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds, width: width, height: height, medium: medium) ?? self
	}
}
