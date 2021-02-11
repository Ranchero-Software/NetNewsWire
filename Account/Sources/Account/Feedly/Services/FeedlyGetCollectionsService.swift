//
//  FeedlyGetCollectionsService.swift
//  Account
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyGetCollectionsService: AnyObject {
	func getCollections(completion: @escaping (Result<[FeedlyCollection], Error>) -> ())
}
