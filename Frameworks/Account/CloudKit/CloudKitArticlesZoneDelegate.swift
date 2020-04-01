//
//  CloudKitArticlesZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import CloudKit

class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var account: Account?
	
	init(account: Account) {
		self.account = account
	}
	
	func cloudKitDidChange(record: CKRecord) {
		// Process everything in the batch method
	}
	
	func cloudKitDidDelete(recordKey: CloudKitRecordKey) {
		// Article downloads clean up old articles and statuses
	}
	
	func cloudKitDidChange(records: [CKRecord]) {
		// TODO
	}
	
	func cloudKitDidDelete(recordKeys: [CloudKitRecordKey]) {
		// Article downloads clean up old articles and statuses
	}
	
}
