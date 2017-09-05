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

final class AttachmentsTable: DatabaseRelatedObjectsTable {

	let name: String
	let databaseIDKey = DatabaseKey.attachmentID

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseTable Methods
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		
		if let attachment = attachmentWithRow(row) {
			return attachment as DatabaseObject
		}
		return nil
	}
	
	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		// TODO
	}
}

private extension AttachmentsTable {

	func attachmentWithRow(_ row: FMResultSet) -> Attachment? {

		guard let attachmentID = row.string(forColumn: DatabaseKey.attachmentID) else {
			return nil
		}
		return Attachment(attachmentID: attachmentID, row: row)
	}
}
