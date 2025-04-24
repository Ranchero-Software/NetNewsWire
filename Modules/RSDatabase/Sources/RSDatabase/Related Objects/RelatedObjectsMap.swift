//
//  RelatedObjectsMap.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Map objectID to [DatabaseObject] (related objects).
// It’s used as the return value for DatabaseLookupTable.fetchRelatedObjects.

public struct RelatedObjectsMap {
	
	private let dictionary: [String: [DatabaseObject]] // objectID: relatedObjects
	
	init(relatedObjects: [DatabaseObject], relatedObjectIDsMap: RelatedObjectIDsMap) {
		
		var d = [String: [DatabaseObject]]()
		let relatedObjectsDictionary = relatedObjects.dictionary()
		
		for objectID in relatedObjectIDsMap.objectIDs() {
			
			if let relatedObjectIDs = relatedObjectIDsMap[objectID] {
				let relatedObjects = relatedObjectIDs.compactMap{ relatedObjectsDictionary[$0] }
				if !relatedObjects.isEmpty {
					d[objectID] = relatedObjects
				}
			}
		}
		
		self.dictionary = d
	}
	
	public func objectIDs() -> Set<String> {
		
		return Set(dictionary.keys)
	}
	
	public subscript(_ objectID: String) -> [DatabaseObject]? {
		return dictionary[objectID]
	}
}
