//
//  FeedlyStreamIDs.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct FeedlyStreamIDs: Decodable, Sendable {

	public let continuation: String?
	public let ids: [String]

	public var isStreamEnd: Bool {
		return continuation == nil
	}
}
