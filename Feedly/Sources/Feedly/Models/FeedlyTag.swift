//
//  FeedlyTag.swift
//  Account
//
//  Created by Kiel Gillard on 3/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyTag: Decodable, Sendable {

	public let id: String
	public let label: String?
}
