//
//  FeedlyFeedContainerValidator.swift
//  Account
//
//  Created by Kiel Gillard on 10/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyFeedContainerValidator {
	var container: Container
	var userId: String?
	
	func getValidContainer() throws -> (Folder, String) {
		guard let folder = container as? Folder else {
			throw FeedlyAccountDelegateError.addFeedChooseFolder
		}
		
		guard let collectionId = folder.externalID else {
			throw FeedlyAccountDelegateError.addFeedInvalidFolder(folder)
		}
		
		guard let userId = userId else {
			throw FeedlyAccountDelegateError.notLoggedIn
		}
		
		let uncategorized = FeedlyCategoryResourceId.Global.uncategorized(for: userId)
		
		guard collectionId != uncategorized.id else {
			throw FeedlyAccountDelegateError.addFeedInvalidFolder(folder)
		}
		
		return (folder, collectionId)
	}
}
