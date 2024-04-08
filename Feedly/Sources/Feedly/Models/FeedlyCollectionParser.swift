//
//  FeedlyCollectionParser.swift
//  Account
//
//  Created by Kiel Gillard on 28/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyCollectionParser: Sendable {

	public let collection: FeedlyCollection

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()
	
	public var folderName: String {
		return rightToLeftTextSantizer.sanitize(collection.label) ?? ""
	}
	
	public var externalID: String {
		return collection.id
	}

	public init(collection: FeedlyCollection) {
		self.collection = collection
	}
}
