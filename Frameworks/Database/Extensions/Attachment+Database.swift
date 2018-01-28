//
//  Attachment+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data
import RSDatabase
import RSParser

extension Attachment {

	init?(row: FMResultSet) {

		guard let url = row.string(forColumn: DatabaseKey.url) else {
			return nil
		}

		let attachmentID = row.string(forColumn: DatabaseKey.attachmentID)
		let mimeType = row.string(forColumn: DatabaseKey.mimeType)
		let title = row.string(forColumn: DatabaseKey.title)
		let sizeInBytes = optionalIntForColumn(row, DatabaseKey.sizeInBytes)
		let durationInSeconds = optionalIntForColumn(row, DatabaseKey.durationInSeconds)

		self.init(attachmentID: attachmentID, url: url, mimeType: mimeType, title: title, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds)
	}

	init?(parsedAttachment: ParsedAttachment) {

		self.init(attachmentID: nil, url: parsedAttachment.url, mimeType: parsedAttachment.mimeType, title: parsedAttachment.title, sizeInBytes: parsedAttachment.sizeInBytes, durationInSeconds: parsedAttachment.durationInSeconds)
	}

	static func attachmentsWithParsedAttachments(_ parsedAttachments: Set<ParsedAttachment>?) -> Set<Attachment>? {

		guard let parsedAttachments = parsedAttachments else {
			return nil
		}

		let attachments = parsedAttachments.compactMap{ Attachment(parsedAttachment: $0) }
		return attachments.isEmpty ? nil : Set(attachments)
	}

}

private func optionalIntForColumn(_ row: FMResultSet, _ columnName: String) -> Int? {
	
	let intValue = row.long(forColumn: columnName)
	if intValue < 1 {
		return nil
	}
	return intValue
}

extension Attachment: DatabaseObject {
	
	public var databaseID: String {
		get {
			return attachmentID
		}
	}

	public func databaseDictionary() -> NSDictionary? {

		let d = NSMutableDictionary()

		d[DatabaseKey.attachmentID] = attachmentID
		d[DatabaseKey.url] = url

		if let mimeType = mimeType {
			d[DatabaseKey.mimeType] = mimeType
		}
		if let title = title {
			d[DatabaseKey.title] = title
		}
		if let sizeInBytes = sizeInBytes {
			d[DatabaseKey.sizeInBytes] = NSNumber(value: sizeInBytes)
		}
		if let durationInSeconds = durationInSeconds {
			d[DatabaseKey.durationInSeconds] = NSNumber(value: durationInSeconds)
		}

		return (d.copy() as! NSDictionary)
	}

}

extension Set where Element == Attachment {

	func databaseDictionaries() -> [NSDictionary] {

		return self.compactMap { $0.databaseDictionary() }
	}

	func databaseObjects() -> [DatabaseObject] {

		return self.compactMap { $0 as DatabaseObject }
	}
}
