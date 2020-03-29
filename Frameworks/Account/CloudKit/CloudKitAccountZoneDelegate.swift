//
//  CloudKitAccountZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/29/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitAcountZoneDelegate: CloudKitZoneDelegate {
	
	weak var account: Account?
	
	init(account: Account) {
		self.account = account
	}
	
	func cloudKitDidChange(record: CKRecord) {
		switch record.recordType {
		case CloudKitAccountZone.CloudKitWebFeed.recordType:
			addWebFeed(record)
		default:
			assertionFailure("Unknown record type: \(record.recordType)")
		}
	}
	
	func cloudKitDidDelete(recordType: CKRecord.RecordType, recordID: CKRecord.ID) {
		switch recordType {
		case CloudKitAccountZone.CloudKitWebFeed.recordType:
			removeWebFeed(recordID.externalID)
		default:
			assertionFailure("Unknown record type: \(recordID.externalID)")
		}
	}

	func addWebFeed(_ record: CKRecord) {
		
	}
	
	func removeWebFeed(_ externalID: String) {
		
	}
	
}
