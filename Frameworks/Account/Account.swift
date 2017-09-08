//
//  Account.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

// Various model objects include an accountInfo property that Accounts can use to store extra data.
public typealias AccountInfo = [String: Any]

public enum AccountType: Int {

	// Raw values should not change since they’re stored on disk.
	case onMyMac = 1
	case feedly = 16
	case feedbin = 17
	case feedWrangler = 18
	case newsBlur = 19
	// TODO: more
}

public final class Account: Hashable {

	public let identifier: String
	public let type: AccountType
	public var nameForDisplay: String?
	public let delegate: AccountDelegate
	public let hashValue: Int
	let settingsFile: String
	let dataFolder: String
	var topLevelObjects = [AnyObject]()
	var feedIDDictionary = [String: Feed]()
	var username: String?
	var accountInfo = AccountInfo()
	
	init(settingsFile: String, type: AccountType, dataFolder: String, identifier: String, delegate: AccountDelegate) {

		self.identifier = identifier
		self.type = type
		self.settingsFile = settingsFile
		self.dataFolder = dataFolder
		self.delegate = delegate
		self.hashValue = identifier.hashValue
	}
	
	public class func ==(lhs: Account, rhs: Account) -> Bool {
		
		return lhs === rhs
	}
}

extension Account: Container {
	
	public func hasAtLeastOneFeed() -> Bool {
	
		return !feedIDDictionary.isEmpty
	}

	public func flattenedFeeds() -> Set<Feed> {
		
		return Set(feedIDDictionary.values)
	}
	
	public func existingFeed(with feedID: String) -> Feed? {
		
		return feedIDDictionary[feedID]
	}
	
	public func canAddItem(_ item: AnyObject) -> Bool {
		
		return delegate.canAddItem(item, toContainer: self)
	}
	
	public func isChild(_ obj: AnyObject) -> Bool {
		
		return topLevelObjects.contains(where: { (oneObject) -> Bool in
			return oneObject === obj
		})
	}
	
	public func visitObjects(_ recurse: Bool, _ visitBlock: VisitBlock) -> Bool {
		
		for oneObject in topLevelObjects {
			
			if let oneContainer = oneObject as? Container {
				if visitBlock(oneObject) {
					return true
				}
				if recurse && oneContainer.visitObjects(recurse, visitBlock) {
					return true
				}
			}
			else {
				if visitBlock(oneObject) {
					return true
				}
			}
		}
		
		return false
	}
}

extension Account: PlistProvider {
	
	public func plist() -> AnyObject? {
		return nil // TODO
	}
}

