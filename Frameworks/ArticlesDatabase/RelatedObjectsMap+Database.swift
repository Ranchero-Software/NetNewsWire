//
//  RelatedObjectsMap+Database.swift
//  Database
//
//  Created by Brent Simmons on 9/13/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Articles

extension RelatedObjectsMap {
	
	func attachments(for articleID: String) -> Set<Attachment>? {
		if let objects = self[articleID] {
			return objects.asAttachments()
		}
		return nil
	}

	func authors(for articleID: String) -> Set<Author>? {
		if let objects = self[articleID] {
			return objects.asAuthors()
		}
		return nil
	}
}
