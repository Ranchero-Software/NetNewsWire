//
//  FeedlyAccountDelegateError.swift
//  Account
//
//  Created by Kiel Gillard on 9/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum FeedlyAccountDelegateError: LocalizedError {
	case notLoggedIn
	case unexpectedResourceId(String)
	case unableToAddFolder(String)
	case unableToRenameFolder(String, String)
	case unableToRemoveFolder(String)
	case unableToMoveFeedBetweenFolders(WebFeed, Folder, Folder)
	case addFeedChooseFolder
	case addFeedInvalidFolder(Folder)
	case unableToRenameFeed(String, String)
	case unableToRemoveFeed(WebFeed)
	
	var errorDescription: String? {
		switch self {
		case .notLoggedIn:
            return String(localized: "Please add the Feedly account again. If this problem persists, open Keychain Access and delete all feedly.com entries, then try again.", bundle: .module, comment: "Feedly – Credentials not found.")
			
		case .unexpectedResourceId(let resourceId):
            let template = String(localized: "Could not encode the identifier “%@”.", bundle: .module, comment: "Feedly – Could not encode resource id to send to Feedly.")
			return String(format: template, resourceId)
			
		case .unableToAddFolder(let name):
            let template = String(localized: "Could not create a folder named “%@”.", bundle: .module, comment: "Feedly – Could not create a folder/collection.")
			return String(format: template, name)
			
		case .unableToRenameFolder(let from, let to):
            let template = String(localized: "Could not rename “%@” to “%@”.", bundle: .module, comment: "Feedly – Could not rename a folder/collection.")
			return String(format: template, from, to)
			
		case .unableToRemoveFolder(let name):
            let template = String(localized: "Could not remove the folder named “%@”.", bundle: .module, comment: "Feedly – Could not remove a folder/collection.")
			return String(format: template, name)
			
		case .unableToMoveFeedBetweenFolders(let feed, _, let to):
            let template = String(localized: "Could not move “%@” to “%@”.", bundle: .module, comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
            return String(localized: "Please choose a folder to contain the feed.", bundle: .module, comment: "Feedly – Feed can only be added to folders.")
			
		case .addFeedInvalidFolder(let invalidFolder):
            let template = String(localized: "Feeds cannot be added to the “%@” folder.", bundle: .module, comment: "Feedly – Feed can only be added to folders.")
			return String(format: template, invalidFolder.nameForDisplay)
			
		case .unableToRenameFeed(let from, let to):
            let template = String(localized: "Could not rename “%@” to “%@”.", bundle: .module, comment: "Feedly – Could not rename a feed.")
			return String(format: template, from, to)
			
		case .unableToRemoveFeed(let feed):
            let template = String(localized: "Could not remove “%@”.", bundle: .module, comment: "Feedly – Could not remove a feed.")
			return String(format: template, feed.nameForDisplay)
		}
	}
	
	var recoverySuggestion: String? {
		switch self {
		case .notLoggedIn:
			return nil
			
		case .unexpectedResourceId:
            let template = String(localized: "Please contact NetNewsWire support.", bundle: .module, comment: "Feedly – Recovery suggestion for not being able to encode a resource id to send to Feedly..")
			return String(format: template)
			
		case .unableToAddFolder:
			return nil
			
		case .unableToRenameFolder:
			return nil
			
		case .unableToRemoveFolder:
			return nil
			
		case .unableToMoveFeedBetweenFolders(let feed, let from, let to):
            let template = String(localized: "“%@” may be in both “%@” and “%@”.", bundle: .module, comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, from.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
			return nil
			
		case .addFeedInvalidFolder:
            return String(localized: "Please choose a different folder to contain the feed.", bundle: .module, comment: "Feedly – Feed can only be added to folders recovery suggestion.")
			
		case .unableToRemoveFeed:
			return nil
			
		case .unableToRenameFeed:
			return nil
		}
	}
}
