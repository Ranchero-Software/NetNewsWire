//
//  FeedlyCollectionParser.swift
//  Account
//
//  Created by Kiel Gillard on 28/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyCollectionParser {
	let collection: FeedlyCollection

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()
	
	var folderName: String {
		return rightToLeftTextSantizer.sanitize(collection.label) ?? ""
	}
	
	var externalID: String {
		return collection.id
	}
}
