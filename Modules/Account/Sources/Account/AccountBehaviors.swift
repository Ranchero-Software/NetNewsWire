//
//  AccountBehaviors.swift
//  Account
//
//  Created by Maurice Parker on 9/20/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/**
	Account specific behaviors are used to support different sync services.  These sync
    services don't all act the same and we need to reflect their differences in the
    user interface as much as possible.  For example some sync services don't allow
    feeds to be in the root folder of the account.
*/
public typealias AccountBehaviors = [AccountBehavior]

public enum AccountBehavior: Equatable {
	
	/**
	  Account doesn't support copies of a feed that are in a folder to be made to the root folder.
	*/
	case disallowFeedCopyInRootFolder
	
	/**
	 Account doesn't support feeds in the root folder.
	*/
	case disallowFeedInRootFolder
	
	/**
	 Account doesn't support a feed being in more than one folder.
	*/
	case disallowFeedInMultipleFolders
	
	/**
	Account doesn't support folders
	*/
	case disallowFolderManagement
	
	/**
	 Account doesn't support OPML imports
	*/
	case disallowOPMLImports
	
	/**
	Account doesn't allow mark as read after a period of days
	*/
	case disallowMarkAsUnreadAfterPeriod(Int)

}
