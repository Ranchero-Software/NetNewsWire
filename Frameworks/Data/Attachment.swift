//
//  Attachment.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Attachment: Equatable {

	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?

	init(url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {

		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds
	}

	public static func ==(lhs: Attachment, rhs: Attachment) -> Bool {

		return lhs.sizeInBytes == rhs.sizeInBytes && lhs.url == rhs.url && lhs.mimeType == rhs.mimeType && lhs.title == rhs.title && lhs.durationInSeconds == rhs.durationInSeconds
	}
}
