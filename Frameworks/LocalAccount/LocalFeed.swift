//
//  LocalFeed.swift
//  Rainier
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import DataModel
import RSCore

public final class LocalFeed: Feed, PlistProvider, Hashable {

	public let account: Account
	public let url: String
	public let feedID: String
	public var homePageURL: String?
	var username: String?
	public var name: String?
	public var editedName: String?
	public var contentHash: String?
	public var hashValue: Int
	
	private var localAccount: LocalAccount {
		get {
			return account as! LocalAccount
		}
	}
	
	public var conditionalGetInfo: HTTPConditionalGetInfo?
	
	public var unreadCount = 0 {
		didSet {
			postUnreadCountDidChangeNotification()
		}
	}
	
	public var nameForDisplay: String {
		get {
			if let name = editedName {
				return name
			}
			if let name = name {
				return name
			}
			return NSLocalizedString("Untitled", comment: "Feed with no name")
		}
	}

	public var plist: AnyObject? {
		get {
			return createDiskDictionary()
		}
	}
	
	public init(account: Account, url: String, feedID: String) {

		self.account = account
		self.url = url
		self.feedID = feedID
		self.hashValue = feedID.hashValue
	}
	
	// MARK: UnreadCountProvider
	
	public func updateUnreadCount() {
		
		(account as! LocalAccount).updateUnreadCountForFeed(self)
	}
	
	func addToUnreadCount(amount: Int) {

		unreadCount = max(unreadCount + amount, 0)
	}
}

public func ==(lhs: LocalFeed, rhs: LocalFeed) -> Bool {

	if lhs === rhs {
		return true
	}
	return lhs.hashValue == rhs.hashValue && lhs.account === rhs.account && lhs.url == rhs.url && lhs.feedID == rhs.feedID && lhs.homePageURL == rhs.homePageURL && lhs.name == rhs.name && lhs.editedName == rhs.editedName
}


// MARK: Disk dictionary

let feedIDKey = "feedID"
let feedURLKey = "url"
private let feedHomePageKey = "home"
private let feedNameKey = "name"
private let feedEditedNameKey = "editedName"
private let feedUsernameKey = "username"
private let feedArticleIDsKey = "articleIDs"
private let feedConditionalGetInfoKey = "conditionalGetInfo"
private let feedContentHashKey = "contentHash"

public extension LocalFeed {
	
	public convenience init?(account: Account, diskDictionary: NSDictionary) {

		guard let feedURL = diskDictionary[feedURLKey] as? String else {
			return nil
		}

		let feedID: String // If not present, it’s same as the feed URL.
		if let tempFeedID = diskDictionary[feedIDKey] as? String {
			feedID = tempFeedID
		}
		else {
			feedID = feedURL
		}

		self.init(account: account, url: feedURL, feedID: feedID)
		
		if let homePageURL = diskDictionary[feedHomePageKey] as? String {
			self.homePageURL = homePageURL
		}
		
		if let name = diskDictionary[feedNameKey] as? String {
			self.name = name
		}
		if let editedName = diskDictionary[feedEditedNameKey] as? String {
			self.editedName = editedName
		}
		if let username = diskDictionary[feedUsernameKey] as? String {
			self.username = username
		}
		if let unreadCount = diskDictionary[unreadCountKey] as? Int {
			self.unreadCount = unreadCount
		}

		if let conditionalGetInfoPlist = diskDictionary[feedConditionalGetInfoKey] as? NSDictionary {
			if conditionalGetInfoPlist.count > 0 {
				self.conditionalGetInfo = HTTPConditionalGetInfo(plist: conditionalGetInfoPlist)
			}
		}

		if let contentHash = diskDictionary[feedContentHashKey] as? String {
			self.contentHash = contentHash
		}
	}

	fileprivate func createDiskDictionary() -> NSDictionary {
		
		let d = NSMutableDictionary()

		d.setObjectWithStringKey(url as NSString, feedURLKey)
		if feedID != url {
			d.setObjectWithStringKey(feedID as NSString, feedIDKey)
		}

		if unreadCount > 0 {
			d.setObjectWithStringKey(NSNumber(value: unreadCount), unreadCountKey)
		}

		d.setOptionalStringValue(homePageURL, feedHomePageKey)
		d.setOptionalStringValue(name, feedNameKey)
		d.setOptionalStringValue(editedName, feedEditedNameKey)
		d.setOptionalStringValue(username, feedUsernameKey)
		d.setOptionalStringValue(contentHash, feedContentHashKey)

		if let conditionalGetInfoPlist = conditionalGetInfo?.plist as? NSDictionary {
			d.setObjectWithStringKey(conditionalGetInfoPlist, feedConditionalGetInfoKey)
		}

		return d
	}

}
