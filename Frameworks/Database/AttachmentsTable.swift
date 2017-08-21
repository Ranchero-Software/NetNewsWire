//
//  AttachmentsTable.swift
//  Database
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

struct AttachmentsTable: DatabaseTable {

	let name: String
	let databaseIDKey = DatabaseKey.attachmentID
	private let cache = DatabaseObjectCache()

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseTable Methods
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		
		return attachmentWithRow(row) as DatabaseObject
	}
}

private extension AttachmentsTable {

	func attachmentWithRow(_ row: FMResultSet) -> Attachment? {

		let attachmentID = row.string(forColumn: DatabaseKey.attachmentID)
		if let cachedAttachment = cache(attachmentID) {
			return cachedAttachment
		}

		return Attachment(attachmentID: attachmentID, row: row)
	}
}
