//
//  FeedlyTag.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyTag: Decodable, Sendable, Equatable {

	public let id: String
	public let label: String?

	public static func ==(lhs: FeedlyTag, rhs: FeedlyTag) -> Bool {
		lhs.id == rhs.id && lhs.label == rhs.label
	}
}
