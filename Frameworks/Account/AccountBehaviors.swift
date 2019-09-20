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
public struct AccountBehaviors: OptionSet {
	
	/**
	  Account doesn't support copies of a feed that are in a folder to be made to the root folder.
	*/
	public static let disallowFeedCopyInRootFolder = AccountBehaviors(rawValue: 1)
	
	/**
	 Account doesn't support feeds in the root folder.
	*/
	public static let disallowFeedInRootFolder = AccountBehaviors(rawValue: 2)
	
	/**
	 Account doesn't support OPML imports
	*/
	public static let disallowOPMLImports = AccountBehaviors(rawValue: 3)
	
	public let rawValue: Int
	public init(rawValue: Int) {
		self.rawValue = rawValue
	}
}
