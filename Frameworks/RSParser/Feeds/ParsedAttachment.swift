//
//  ParsedAttachment.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct ParsedAttachment: Hashable {

	public let url: String?
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?
	public let hashValue: Int
	
	init(url: String?, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {

		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds
		
		var stringToHash = ""
		stringToHash += url ?? ""
		stringToHash += mimeType ?? ""
		stringToHash += title ?? ""
		var h = stringToHash.hashValue
		if let sizeInBytes = sizeInBytes {
			h = h ^ sizeInBytes.hashValue
		}
		if let durationInSeconds = durationInSeconds {
			h = h ^ durationInSeconds.hashValue
		}
		self.hashValue = h
	}
	
	public static func ==(lhs: ParsedAttachment, rhs: ParsedAttachment) -> Bool {
		
		return lhs.hashValue == rhs.hashValue && lhs.url == rhs.url && lhs.mimeType == rhs.mimeType && lhs.title == rhs.title && lhs.sizeInBytes == rhs.sizeInBytes && lhs.durationInSeconds == rhs.durationInSeconds
	}
}
