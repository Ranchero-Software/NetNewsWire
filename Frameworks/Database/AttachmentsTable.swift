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
	var cache = [String: Attachment]()

	init(name: String) {

		self.name = name
	}
	
	// MARK: DatabaseRelatedObjectsTable

	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]? {

		if databaseIDs.isEmpty {
			return nil
		}

		var cachedAttachments = Set<Attachment>()
		var databaseIDsToFetch = Set<String>()

		for attachmentID in databaseIDs {
			if let cachedAttachment = cache[attachmentID] {
				cachedAttachments.insert(cachedAttachment)
			}
			else {
				databaseIDsToFetch.insert(attachmentID)
			}
		}

		if databaseIDsToFetch.isEmpty {
			return cachedAttachments.databaseObjects()
		}

		guard let resultSet = selectRowsWhere(key: databaseIDKey, inValues: Array(databaseIDsToFetch), in: database) else {
			return cachedAttachments.databaseObjects()
		}
		let fetchedDatabaseObjects = objectsWithResultSet(resultSet)
		let fetchedAttachments = Set(fetchedDatabaseObjects.map { $0 as Attachment })
		cacheAttachments(fetchedAttachments)

		let allAttachments = cachedAttachments.union(fetchedAttachments)
		return allAttachments.databaseObjects()
	}

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

		cacheAttachments(attachmentsToSave)
		
		insertRows(attachmentsToSave.databaseDictionaries(), insertType: .orIgnore, in: database)
	}
}

private extension AttachmentsTable {

	func cacheAttachments(_ attachments: Set<Attachment>) {

		for attachment in attachments {
			cache[attachment.attachmentID] = attachment
		}
	}

	func attachmentWithRow(_ row: FMResultSet) -> Attachment? {

		// attachmentID is non-null in database schema.
		let attachmentID = row.string(forColumn: DatabaseKey.attachmentID)!
		return Attachment(attachmentID: attachmentID, row: row)
	}
}

