//
//  Account.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Data

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

	// MARK: - API

	func refreshAll() {

		delegate.refreshAll()
	}
}


extension Account: PlistProvider {
	
	public func plist() -> AnyObject? {
		return nil // TODO
	}
}

extension Account: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {

		var s = ""
		for oneObject in topLevelObjects {
			if let oneOPMLObject = oneObject as? OPMLRepresentable {
				s += oneOPMLObject.OPMLString(indentLevel: indentLevel + 1)
			}
		}
		return s
	}
}
