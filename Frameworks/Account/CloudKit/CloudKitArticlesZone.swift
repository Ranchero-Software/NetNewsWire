//
//  CloudKitArticlesZone.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import CloudKit
import SyncDatabase

final class CloudKitArticlesZone: CloudKitZone {
	
	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.ID(zoneName: "Articles", ownerName: CKCurrentUserDefaultName)
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var container: CKContainer?
	weak var database: CKDatabase?
	weak var refreshProgress: DownloadProgress? = nil
	var delegate: CloudKitZoneDelegate? = nil
	
	struct CloudKitArticleStatus {
		static let recordType = "ArticleStatus"
		struct Fields {
			static let read = "read"
			static let starred = "starred"
			static let userDeleted = "userDeleted"
		}
	}
	
	init(container: CKContainer) {
		self.container = container
		self.database = container.privateCloudDatabase
	}
	
	func sendArticleStatus(_ syncStatuses: [SyncStatus], completion: @escaping ((Result<Void, Error>) -> Void)) {
		var records = [String: CKRecord]()
		
		for status in syncStatuses {
			
			var record = records[status.articleID]
			if record == nil {
				let recordID = CKRecord.ID(recordName: status.articleID, zoneID: Self.zoneID)
				record = CKRecord(recordType: CloudKitArticleStatus.recordType, recordID: recordID)
				records[status.articleID] = record
			}
			
			switch status.key {
			case .read:
				record![CloudKitArticleStatus.Fields.read] = status.flag ? "1" : "0"
			case .starred:
				record![CloudKitArticleStatus.Fields.starred] = status.flag ? "1" : "0"
			case .userDeleted:
				record![CloudKitArticleStatus.Fields.userDeleted] = status.flag ? "1" : "0"
			}
		}
		
		modify(recordsToSave: Array(records.values), recordIDsToDelete: [], completion: completion)
	}
	
}
