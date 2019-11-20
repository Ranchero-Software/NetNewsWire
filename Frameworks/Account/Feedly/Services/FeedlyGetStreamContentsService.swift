//
//  FeedlyGetStreamContentsService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyGetStreamContentsService: class {
	func getStreamContents(for resource: FeedlyResourceId, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completionHandler: @escaping (Result<FeedlyStream, Error>) -> ())
}
