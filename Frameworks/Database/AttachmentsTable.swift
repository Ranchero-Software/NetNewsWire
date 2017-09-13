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
	var cache = DatabaseObjectCache()

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseRelatedObjectsTable

	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		
		if let attachment = attachmentWithRow(row) {
			return attachment as DatabaseObject
		}
		return nil
	}
	
	func save(_ objects: [DatabaseObject], in database: FMDatabase) {

		let attachments = objects.map { $0 as! Attachment }

		// Attachments in cache must already exist in database. Filter them out.
		let attachmentsToSave = Set(attachments.filter { (attachment) -> Bool in
			if let _ = cache[attachment.attachmentID] {
				return false
			}
			return true
		})

		cache.add(attachmentsToSave.databaseObjects())
		
		insertRows(attachmentsToSave.databaseDictionaries(), insertType: .orIgnore, in: database)
	}
}

private extension AttachmentsTable {

	func attachmentWithRow(_ row: FMResultSet) -> Attachment? {

		// attachmentID is non-null in database schema.
		let attachmentID = row.string(forColumn: DatabaseKey.attachmentID)!
		return Attachment(attachmentID: attachmentID, row: row)
	}
}

