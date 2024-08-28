//
//  ParsedAttachment.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedAttachment: Hashable, Sendable {

	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?

	public init?(url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {
		if url.isEmpty {
			return nil
		}
		
		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}
}
