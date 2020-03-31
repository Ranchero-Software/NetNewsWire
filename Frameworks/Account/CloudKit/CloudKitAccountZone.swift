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

	typealias ContainerWebFeed = (webFeedExternalID: String, containerWebFeedExternalID: String, containerExternalID: String)
	
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
	
	struct CloudKitContainer {
		static let recordType = "Container"
		struct Fields {
			static let isAccount = "isAccount"
			static let name = "name"
		}
	}
	
	struct CloudKitContainerWebFeed {
		static let recordType = "ContainerWebFeed"
		struct Fields {
			static let container = "container"
			static let webFeed = "webFeed"
		}
	}
	
	init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
    }
    
	///  Persist a web feed record to iCloud and return the external key
	func createWebFeed(url: String, editedName: String?, container: Container, completion: @escaping (Result<ContainerWebFeed, Error>) -> Void) {
		let webFeedRecord = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: generateRecordID())
		webFeedRecord[CloudKitWebFeed.Fields.url] = url
		if let editedName = editedName {
			webFeedRecord[CloudKitWebFeed.Fields.editedName] = editedName
		}
		
		guard let containerExternalID = container.externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}
		
		let containerRecordID = CKRecord.ID(recordName: containerExternalID, zoneID: Self.zoneID)
		let containerWebFeedRecord = CKRecord(recordType: CloudKitContainerWebFeed.recordType, recordID: generateRecordID())
		containerWebFeedRecord[CloudKitContainerWebFeed.Fields.container] = CKRecord.Reference(recordID: containerRecordID, action: .deleteSelf)
		containerWebFeedRecord[CloudKitContainerWebFeed.Fields.webFeed] = CKRecord.Reference(record: webFeedRecord, action: .deleteSelf)

		save([webFeedRecord, containerWebFeedRecord]) { result in
			switch result {
			case .success:
				let cwf = ContainerWebFeed(webFeedExternalID: webFeedRecord.externalID,
										   containerWebFeedExternalID: containerWebFeedRecord.externalID,
										   containerExternalID: containerExternalID)
				completion(.success(cwf))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	/// Rename the given web feed
	func renameWebFeed(_ webFeed: WebFeed, editedName: String?, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = webFeed.externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: Self.zoneID)
		let record = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: recordID)
		record[CloudKitWebFeed.Fields.editedName] = editedName
		
		save([record]) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	/// Deletes a web feed from iCloud
	func removeWebFeed(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {
		delete(externalID: webFeed.externalID , completion: completion)
	}
	
	func findOrCreateAccount(completion: @escaping (Result<String, Error>) -> Void) {
		let predicate = NSPredicate(format: "isAccount = \"true\"")
		let ckQuery = CKQuery(recordType: CloudKitContainer.recordType, predicate: predicate)
		
		query(ckQuery) { result in
			switch result {
			case .success(let records):
				completion(.success(records[0].externalID))
			case .failure:
				self.createContainer(name: "Account", isAccount: true, completion: completion)
			}
		}
	}
	
	func createFolder(name: String, completion: @escaping (Result<String, Error>) -> Void) {
		createContainer(name: name, isAccount: false, completion: completion)
	}
	
	func renameFolder(_ folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = folder.externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: Self.zoneID)
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: recordID)
		record[CloudKitContainer.Fields.name] = name
		
		save([record]) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		delete(externalID: folder.externalID, completion: completion)
	}
	
}

private extension CloudKitAccountZone {
	
	func createContainer(name: String, isAccount: Bool, completion: @escaping (Result<String, Error>) -> Void) {
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: generateRecordID())
		record[CloudKitContainer.Fields.name] = name
		record[CloudKitContainer.Fields.isAccount] = isAccount ? "true" : "false"

		save([record]) { result in
			switch result {
			case .success:
				completion(.success(record.externalID))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
}
