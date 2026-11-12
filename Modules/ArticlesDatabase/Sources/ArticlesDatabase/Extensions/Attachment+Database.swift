//
//  Attachment+Database.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation
import Articles
import RSParser

extension Attachment {

	init?(parsedAttachment: ParsedAttachment) {
		let medium = Medium(parsedMedium: parsedAttachment.medium)
		self.init(url: parsedAttachment.url, mimeType: parsedAttachment.mimeType, title: parsedAttachment.title, sizeInBytes: parsedAttachment.sizeInBytes, durationInSeconds: parsedAttachment.durationInSeconds, width: parsedAttachment.width, height: parsedAttachment.height, medium: medium)
	}

	/// Keeps the order, dropping repeats of a URL.
	public static func attachmentsWithParsedAttachments(_ parsedAttachments: [ParsedAttachment]?) -> [Attachment]? {
		guard let parsedAttachments else {
			return nil
		}

		var urls = Set<String>()
		let attachments = parsedAttachments.filter { urls.insert($0.url).inserted }.compactMap { Attachment(parsedAttachment: $0) }
		return attachments.isEmpty ? nil : attachments
	}
}

extension Attachment.Medium {

	init?(parsedMedium: ParsedAttachment.Medium?) {
		guard let parsedMedium else {
			return nil
		}
		self.init(rawValue: parsedMedium.rawValue)
	}
}
