//
//  CloudKitAccountZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import CloudKit

final class CloudKitAccountZone: CloudKitZone {

	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.ID(zoneName: "Account", ownerName: CKCurrentUserDefaultName)
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

    weak var container: CKContainer?
    weak var database: CKDatabase?
	weak var refreshProgress: DownloadProgress?
	var delegate: CloudKitZoneDelegate? = nil
    
	struct CloudKitWebFeed {
		static let recordType = "WebFeed"
		struct Fields {
			static let url = "url"
			static let editedName = "editedName"
		}
	}
	
	init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
    }
    
	///  Persist a web feed record to iCloud and return the external key
	func createWebFeed(url: String, editedName: String?, completion: @escaping (Result<String, Error>) -> Void) {
		let record = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: generateRecordID())
		record[CloudKitWebFeed.Fields.url] = url
		if let editedName = editedName {
			record[CloudKitWebFeed.Fields.editedName] = editedName
		}
		
		save(record: record) { result in
			switch result {
			case .success:
				completion(.success(record.externalID))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func removeWebFeed(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = webFeed.externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}
		delete(externalID: externalID, completion: completion)
	}
	
}
