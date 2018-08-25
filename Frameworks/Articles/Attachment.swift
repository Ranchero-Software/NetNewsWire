//
//  Attachment.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct Attachment: Hashable {

	public let attachmentID: String // Calculated
	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?

	public init(attachmentID: String?, url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?) {

		self.url = url
		self.mimeType = mimeType
		self.title = title
		if let sizeInBytes = sizeInBytes, sizeInBytes > 0 {
			self.sizeInBytes = sizeInBytes
		}
		else {
			self.sizeInBytes = nil
		}
		if let durationInSeconds = durationInSeconds, durationInSeconds > 0 {
			self.durationInSeconds = durationInSeconds
		}
		else {
			self.durationInSeconds = nil
		}

		if let attachmentID = attachmentID {
			self.attachmentID = attachmentID
		}
		else {
			var s = url
			s += mimeType ?? ""
			s += title ?? ""
			if let sizeInBytes = sizeInBytes {
				s += "\(sizeInBytes)"
			}
			if let durationInSeconds = durationInSeconds {
				s += "\(durationInSeconds)"
			}
			self.attachmentID = databaseIDWithString(s)
		}
	}
}
