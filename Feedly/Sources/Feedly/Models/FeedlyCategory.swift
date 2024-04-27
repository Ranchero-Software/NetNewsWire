//
//  FeedlyCategory.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyCategory: Decodable, Sendable, Equatable {

    public let label: String
	public let id: String

	public static func ==(lhs: FeedlyCategory, rhs: FeedlyCategory) -> Bool {
		lhs.label == rhs.label && lhs.id == rhs.id
	}
}
