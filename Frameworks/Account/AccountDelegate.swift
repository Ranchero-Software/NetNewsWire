//
//  AccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol AccountDelegate {

	// Local account does not; some synced accounts might.
	var supportsSubFolders: Bool { get }

	func refreshAll(for account: Account)

}
