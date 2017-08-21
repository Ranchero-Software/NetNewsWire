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

extension Attachment {

	init?(attachmentID: String, row: FMResultSet) {

		guard let url = row.string(forColumn: DatabaseKey.url) else {
			return nil
		}

		let mimeType = row.string(forColumn: DatabaseKey.mimeType)
		let title = row.string(forColumn: DatabaseKey.title)
		let sizeInBytes = optionalIntForColumn(row, DatabaseKey.sizeInBytes)
		let durationInSeconds = optionalIntForColumn(row, DatabaseKey.durationInSeconds)

		self.init(attachmentID: attachmentID, url: url, mimeType: mimeType, title: title, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds)
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
}
