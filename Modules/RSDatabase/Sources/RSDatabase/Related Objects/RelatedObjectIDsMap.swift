//
//  RelatedObjectIDsMap.swift
//  RSDatabase
//
//  Created by Brent Simmons on 9/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Maps objectIDs to Set<String> where the Strings are relatedObjectIDs.

struct RelatedObjectIDsMap {
	
	private let dictionary: [String: Set<String>] // objectID: Set<relatedObjectID>
	
	init(dictionary: [String: Set<String>]) {
		
		self.dictionary = dictionary
	}
	
	init(lookupValues: Set<LookupValue>) {
		
		var d = [String: Set<String>]()
		
		for lookupValue in lookupValues {
			let objectID = lookupValue.objectID
			let relatedObjectID: String = lookupValue.relatedObjectID
			if d[objectID] == nil {
				d[objectID] = Set([relatedObjectID])
			}
			else {
				d[objectID]!.insert(relatedObjectID)
			}
		}
		
		self.init(dictionary: d)
	}
	
	func objectIDs() -> Set<String> {
		
		return Set(dictionary.keys)
	}
	
	func relatedObjectIDs() -> Set<String> {
		
		var ids = Set<String>()
		for (_, relatedObjectIDs) in dictionary {
			ids.formUnion(relatedObjectIDs)
		}
		return ids
	}
	
	subscript(_ objectID: String) -> Set<String>? {
		return dictionary[objectID]
	}
}

struct LookupValue: Hashable {

	let objectID: String
	let relatedObjectID: String
}
