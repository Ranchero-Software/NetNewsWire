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
	case unableToAddFolder(String)
	case unableToRenameFolder(String, String)
	case unableToRemoveFolder(String)
	case unableToMoveFeedBetweenFolders(Feed, Folder, Folder)
	case addFeedChooseFolder
	case addFeedInvalidFolder(Folder)
	case unableToRenameFeed(String, String)
	case unableToRemoveFeed(Feed)
	
	var errorDescription: String? {
		switch self {
		case .notLoggedIn:
			return NSLocalizedString("Please add the Feedly account again.", comment: "Feedly – Credentials not found.")
			
		case .unableToAddFolder(let name):
			let template = NSLocalizedString("Could not create a folder named “%@”.", comment: "Feedly – Could not create a folder/collection.")
			return String(format: template, name)
			
		case .unableToRenameFolder(let from, let to):
			let template = NSLocalizedString("Could not rename “%@” to “%@”.", comment: "Feedly – Could not rename a folder/collection.")
			return String(format: template, from, to)
			
		case .unableToRemoveFolder(let name):
			let template = NSLocalizedString("Could not remove the folder named “%@”.", comment: "Feedly – Could not remove a folder/collection.")
			return String(format: template, name)
			
		case .unableToMoveFeedBetweenFolders(let feed, _, let to):
			let template = NSLocalizedString("Could not move “%@” to “%@”.", comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
			return NSLocalizedString("Please choose a folder to contain the feed.", comment: "Feedly – Feed can only be added to folders.")
			
		case .addFeedInvalidFolder(let invalidFolder):
			let template = NSLocalizedString("Feeds cannot be added to the “%@” folder.", comment: "Feedly – Feed can only be added to folders.")
			return String(format: template, invalidFolder.nameForDisplay)
			
		case .unableToRenameFeed(let from, let to):
			let template = NSLocalizedString("Could not rename “%@” to “%@”.", comment: "Feedly – Could not rename a feed.")
			return String(format: template, from, to)
			
		case .unableToRemoveFeed(let feed):
			let template = NSLocalizedString("Could not remove “%@”.", comment: "Feedly – Could not remove a feed.")
			return String(format: template, feed.nameForDisplay)
		}
	}
	
	var recoverySuggestion: String? {
		switch self {
		case .notLoggedIn:
			return nil
			
		case .unableToAddFolder:
			return nil
			
		case .unableToRenameFolder:
			return nil
			
		case .unableToRemoveFolder:
			return nil
			
		case .unableToMoveFeedBetweenFolders(let feed, let from, let to):
			let template = NSLocalizedString("“%@” may be in both “%@” and “%@”.", comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, from.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
			return nil
			
		case .addFeedInvalidFolder:
			return NSLocalizedString("Please choose a different folder to contain the feed.", comment: "Feedly – Feed can only be added to folders recovery suggestion.")
			
		case .unableToRemoveFeed:
			return nil
			
		case .unableToRenameFeed:
			return nil
		}
	}
}
