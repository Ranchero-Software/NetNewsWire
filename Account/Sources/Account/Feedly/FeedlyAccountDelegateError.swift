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
            return String(localized: "error.feedly.credentials-not-found", bundle: .module, comment: "Feedly – Credentials not found.")
			
		case .unexpectedResourceId(let resourceId):
            let template = String(localized: "error.message.could-not-encode-identifier-\(resourceId)", bundle: .module, comment: "Feedly – Could not encode resource id to send to Feedly.")
			return String(format: template, resourceId)
			
		case .unableToAddFolder(let name):
            let template = String(localized: "error.message.could-not-create-folder-\(name)", bundle: .module, comment: "Feedly – Could not create a folder/collection.")
			return String(format: template, name)
			
		case .unableToRenameFolder(let from, let to):
            let template = String(localized: "error.message.could-not-rename-folder", bundle: .module, comment: "Feedly – Could not rename a folder/collection.")
			return String(format: template, from, to)
			
		case .unableToRemoveFolder(let name):
            let template = String(localized: "error.message.could-not-remove-folder-\(name)", bundle: .module, comment: "Feedly – Could not remove a folder/collection.")
			return String(format: template, name)
			
		case .unableToMoveFeedBetweenFolders(let feed, _, let to):
            let template = String(localized: "error.message.could-not-move-feed", bundle: .module, comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
            return String(localized: "error.message.folder-not-chosen", bundle: .module, comment: "Feedly – Feed can only be added to folders.")
			
		case .addFeedInvalidFolder(let invalidFolder):
            let template = String(localized: "error.message.could-not-add-to-folder", bundle: .module, comment: "Feedly – Feed can only be added to folders.")
			return String(format: template, invalidFolder.nameForDisplay)
			
		case .unableToRenameFeed(let from, let to):
            let template = String(localized: "error.message.could-not-rename-feed", bundle: .module, comment: "Feedly – Could not rename a feed.")
			return String(format: template, from, to)
			
		case .unableToRemoveFeed(let feed):
            let template = String(localized: "error.message.could-not-remove-feed", bundle: .module, comment: "Feedly – Could not remove a feed.")
			return String(format: template, feed.nameForDisplay)
		}
	}
	
	var recoverySuggestion: String? {
		switch self {
		case .notLoggedIn:
			return nil
			
		case .unexpectedResourceId:
            let template = String(localized: "error.message.contact-support", bundle: .module, comment: "Feedly – Recovery suggestion for not being able to encode a resource id to send to Feedly..")
			return String(format: template)
			
		case .unableToAddFolder:
			return nil
			
		case .unableToRenameFolder:
			return nil
			
		case .unableToRemoveFolder:
			return nil
			
		case .unableToMoveFeedBetweenFolders(let feed, let from, let to):
            let template = String(localized: "error.message.unable-to-move-feed-between-folders", bundle: .module, comment: "Feedly – Could not move a feed between folders/collections.")
			return String(format: template, feed.nameForDisplay, from.nameForDisplay, to.nameForDisplay)
			
		case .addFeedChooseFolder:
			return nil
			
		case .addFeedInvalidFolder:
            return String(localized: "error.message.add-feed-invalid-folder", bundle: .module, comment: "Feedly – Feed can only be added to folders recovery suggestion.")
			
		case .unableToRemoveFeed:
			return nil
			
		case .unableToRenameFeed:
			return nil
		}
	}
}
