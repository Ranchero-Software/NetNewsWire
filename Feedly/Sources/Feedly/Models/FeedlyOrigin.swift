//
//  FeedlyOrigin.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyOrigin: Decodable, Sendable, Equatable {

	public let title: String?
	public let streamID: String?
	public let htmlURL: String?

	public static func ==(lhs: FeedlyOrigin, rhs: FeedlyOrigin) -> Bool {

		lhs.title == rhs.title && lhs.streamID == rhs.streamID && lhs.htmlURL == rhs.htmlURL
	}
}
