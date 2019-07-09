//
//  AttachmentsTable.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/15/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Articles

final class AttachmentsTable: DatabaseRelatedObjectsTable {

	let name: String
	let databaseIDKey = DatabaseKey.attachmentID
	var cache = DatabaseObjectCache()

	init(name: String) {
		self.name = name
	}
	
	// MARK: - DatabaseRelatedObjectsTable

	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		if let attachment = Attachment(row: row) {
			return attachment as DatabaseObject
		}
		return nil
	}
}

