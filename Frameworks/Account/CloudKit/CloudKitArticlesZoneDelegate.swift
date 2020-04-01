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
//		switch record.recordType {
//		case CloudKitAccountZone.CloudKitWebFeed.recordType:
//		default:
//			assertionFailure("Unknown record type: \(record.recordType)")
//		}
	}
	
	func cloudKitDidDelete(recordType: CKRecord.RecordType, recordID: CKRecord.ID) {
		// Article downloads clean up old articles and statuses
	}
	
}
