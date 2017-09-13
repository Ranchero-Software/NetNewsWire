//
//  TagsManager.swift
//  Database
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

// Article->tags is a many-to-many relationship.
// Since a tag is just a String, the tags table and the lookup table are the same table.
// All the heavy lifting is done in DatabaseLookupTable.
//
// CREATE TABLE if not EXISTS tags(tagName TEXT NOT NULL, articleID TEXT NOT NULL, PRIMARY KEY(tagName, articleID));
// CREATE INDEX if not EXISTS tags_tagName_index on tags (tagName COLLATE NOCASE);

final class TagsTable: DatabaseRelatedObjectsTable {
	
	let name: String
	let databaseIDKey = DatabaseKey.tagName
	init(name: String) {

		self.name = name
	}

	// MARK: DatabaseTable Methods
	
	func fetchObjectsWithIDs(_ databaseIDs: Set<String>, in database: FMDatabase) -> [DatabaseObject]? {
		
		// A tag is a string, and it is its own databaseID.
		return databaseIDs.map{ $0 as DatabaseObject }
	}
	
	func objectWithRow(_ row: FMResultSet) -> DatabaseObject? {
		
		return nil //unused
	}
	
	func save(_ objects: [DatabaseObject], in database: FMDatabase) {
		
		// Nothing to do, since tags are saved in the lookup table, not in a separate table.
	}
}

