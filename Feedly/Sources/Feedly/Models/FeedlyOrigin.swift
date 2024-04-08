//
//  FeedlyOrigin.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyOrigin: Decodable, Sendable {

	public let title: String?
	public let streamID: String?
	public let htmlUrl: String?
}
