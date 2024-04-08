//
//  FeedlyAccountDelegateError.swift
//  Account
//
//  Created by Kiel Gillard on 9/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum FeedlyAccountDelegateError: LocalizedError, Sendable {

	case notLoggedIn
	case unexpectedResourceID(String)
	case unableToAddFolder(String)
	case unableToRenameFolder(String, String)
	case unableToRemoveFolder(String)
	case unableToMoveFeedBetweenFolders(String, String, String)
	case addFeedChooseFolder
	case addFeedInvalidFolder(String)
	case unableToRenameFeed(String, String)
	case unableToRemoveFeed(String)

	public var errorDescription: String? {
		switch self {
		case .notLoggedIn:
			return NSLocalizedString("Please add the Feedly account again. If this problem persists, open Keychain Access and delete all feedly.com entries, then try again.", comment: "Feedly – Credentials not found.")
			
		case .unexpectedResourceID(let resourceID):
			let template = NSLocalizedString("Could not encode the identifier “%@”.", comment: "Feedly – Could not encode resource id to send to Feedly.")
			return String(format: template, resourceID)
			
		case .unableToAddFolder(let name):
			let template = NSLocalizedString("Could not create a folder named “%@”.", comment: "Feedly – Could not create a folder/collection.")
			return String(format: template, name)
			
		case .unableToRenameFolder(let from, let to):
			let template = NSLocalizedString("Could not rename “%@” to “%@”.", comment: "Feedly – Could not rename a folder/collection.")
			return String(format: template, from, to)
			
		case .unableToRemoveFolder(let name):
			let template = NSLocalizedString("Could not remove the folder named “%@”.", comment: "Feedly – Could not remove a folder/collection.")
			return String(format: template, name)
			
		case .unableToMoveFeedBetweenFolders(let feedName, _, let destinationFolderName):
			let template = NSLocalizedString("Could not move “%@” to “%@”.", comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feedName, destinationFolderName)

		case .addFeedChooseFolder:
			return NSLocalizedString("Please choose a folder to contain the feed.", comment: "Feedly – Feed can only be added to folders.")
			
		case .addFeedInvalidFolder(let folderName):
			let template = NSLocalizedString("Feeds cannot be added to the “%@” folder.", comment: "Feedly – Feed can only be added to folders.")
			return String(format: template, folderName)

		case .unableToRenameFeed(let from, let to):
			let template = NSLocalizedString("Could not rename “%@” to “%@”.", comment: "Feedly – Could not rename a feed.")
			return String(format: template, from, to)
			
		case .unableToRemoveFeed(let feedName):
			let template = NSLocalizedString("Could not remove “%@”.", comment: "Feedly – Could not remove a feed.")
			return String(format: template, feedName)
		}
	}
	
	public var recoverySuggestion: String? {
		switch self {
		case .notLoggedIn:
			return nil
			
		case .unexpectedResourceID:
			let template = NSLocalizedString("Please contact NetNewsWire support.", comment: "Feedly – Recovery suggestion for not being able to encode a resource id to send to Feedly..")
			return String(format: template)
			
		case .unableToAddFolder:
			return nil
			
		case .unableToRenameFolder:
			return nil
			
		case .unableToRemoveFolder:
			return nil
			
		case .unableToMoveFeedBetweenFolders(let feedName, let sourceFolderName, let destinationFolderName):
			let template = NSLocalizedString("“%@” may be in both “%@” and “%@”.", comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feedName, sourceFolderName, destinationFolderName)

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
