//
//  FeedlyGetStreamContentsService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlyGetStreamContentsService: AnyObject {
	func getStreamContents(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStream, Error>) -> ())
}
