//
//  Account.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum AccountType: Int {

	case onMyMac = 1
	case feedly = 16
	case feedbin
	case feedWrangler
	case newsBlur
}

public final class Account: Container, PlistProvider {

	public let identifier: String
	public let type: AccountType
	public var nameForDisplay: String
	public weak var delegate: AccountDelegate

	init(settingsFile: String, type: AccountType, dataFolder: String, identifier: String, delegate: AccountDelegate) {

		self.identifier = identifier
		self.type = type
		self.settingsFile = settingsFile
		self.dataFolder = dataFolder
		self.delegate = delegate
	}
}
