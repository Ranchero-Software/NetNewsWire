//
//  CloudKitAccountZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSWeb
import RSParser
import CloudKit
import CloudKitSync

enum CloudKitAccountZoneError: LocalizedError {
	case unknown
	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}
final class CloudKitAccountZone: CloudKitZone {

	var zoneID: CKRecordZone.ID

    weak var container: CKContainer?
    weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?

	struct CloudKitFeed {
		static let recordType = "AccountWebFeed"
		struct Fields {
			static let url = "url"
			static let name = "name"
			static let editedName = "editedName"
			static let homePageURL = "homePageURL"
			static let containerExternalIDs = "containerExternalIDs"
		}
	}

	struct CloudKitContainer {
		static let recordType = "AccountContainer"
		struct Fields {
			static let isAccount = "isAccount"
			static let name = "name"
		}
	}

	init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: "Account", ownerName: CKCurrentUserDefaultName)
		migrateChangeToken()
    }

	func importOPML(rootExternalID: String, items: [RSOPMLItem], completion: @escaping (Result<Void, Error>) -> Void) {
		var records = [CKRecord]()
		var feedRecords = [String: CKRecord]()

		func processFeed(feedSpecifier: RSOPMLFeedSpecifier, containerExternalID: String) {
			if let feedRecord = feedRecords[feedSpecifier.feedURL], var containerExternalIDs = feedRecord[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
				containerExternalIDs.append(containerExternalID)
				feedRecord[CloudKitFeed.Fields.containerExternalIDs] = containerExternalIDs
			} else {
				let feedRecord = newFeedCKRecord(feedSpecifier: feedSpecifier, containerExternalID: containerExternalID)
				records.append(feedRecord)
				feedRecords[feedSpecifier.feedURL] = feedRecord
			}
		}

		for item in items {
			if let feedSpecifier = item.feedSpecifier {
				processFeed(feedSpecifier: feedSpecifier, containerExternalID: rootExternalID)
			} else {
				if let title = item.titleFromAttributes {
					let containerRecord = newContainerCKRecord(name: title)
					records.append(containerRecord)
					item.children?.forEach { itemChild in
						if let feedSpecifier = itemChild.feedSpecifier {
							processFeed(feedSpecifier: feedSpecifier, containerExternalID: containerRecord.externalID)
						}
					}
				}
			}
		}

		save(records, completion: completion)
	}

	///  Persist a web feed record to iCloud and return the external key
	func createFeed(url: String, name: String?, editedName: String?, homePageURL: String?, container: Container, completion: @escaping (Result<String, Error>) -> Void) {
		let recordID = CKRecord.ID(recordName: url.md5String, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitFeed.recordType, recordID: recordID)
		record[CloudKitFeed.Fields.url] = url
		record[CloudKitFeed.Fields.name] = name
		if let editedName = editedName {
			record[CloudKitFeed.Fields.editedName] = editedName
		}
		if let homePageURL = homePageURL {
			record[CloudKitFeed.Fields.homePageURL] = homePageURL
		}

		guard let containerExternalID = container.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}
		record[CloudKitFeed.Fields.containerExternalIDs] = [containerExternalID]

		save(record) { result in
			switch result {
			case .success:
				completion(.success(record.externalID))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	/// Rename the given web feed
	func renameFeed(_ feed: Feed, editedName: String?, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = feed.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitFeed.recordType, recordID: recordID)
		record[CloudKitFeed.Fields.editedName] = editedName

		save(record) { result in
			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	/// Removes a web feed from a container and optionally deletes it, calling the completion with true if deleted
	func removeFeed(_ feed: Feed, from: Container, completion: @escaping (Result<Bool, Error>) -> Void) {
		guard let fromContainerExternalID = from.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		fetch(externalID: feed.externalID) { result in
			switch result {
			case .success(let record):

				if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
					var containerExternalIDSet = Set(containerExternalIDs)
					containerExternalIDSet.remove(fromContainerExternalID)

					if containerExternalIDSet.isEmpty {
						self.delete(externalID: feed.externalID) { result in
							switch result {
							case .success:
								completion(.success(true))
							case .failure(let error):
								completion(.failure(error))
							}
						}

					} else {

						record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
						self.save(record) { result in
							switch result {
							case .success:
								completion(.success(false))
							case .failure(let error):
								completion(.failure(error))
							}
						}

					}
				}

			case .failure(let error):
				if let ckError = ((error as? CloudKitError)?.error as? CKError), ckError.code == .unknownItem {
					completion(.success(true))
				} else {
					completion(.failure(error))
				}
			}
		}
	}

	func moveFeed(_ feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let fromContainerExternalID = from.externalID, let toContainerExternalID = to.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		fetch(externalID: feed.externalID) { result in
			switch result {
			case .success(let record):
				if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
					var containerExternalIDSet = Set(containerExternalIDs)
					containerExternalIDSet.remove(fromContainerExternalID)
					containerExternalIDSet.insert(toContainerExternalID)
					record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
					self.save(record, completion: completion)
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func addFeed(_ feed: Feed, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let toContainerExternalID = to.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		fetch(externalID: feed.externalID) { result in
			switch result {
			case .success(let record):
				if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
					var containerExternalIDSet = Set(containerExternalIDs)
					containerExternalIDSet.insert(toContainerExternalID)
					record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
					self.save(record, completion: completion)
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func findFeedExternalIDs(for folder: Folder, completion: @escaping (Result<[String], Error>) -> Void) {
		guard let folderExternalID = folder.externalID else {
			completion(.failure(CloudKitAccountZoneError.unknown))
			return
		}

		let predicate = NSPredicate(format: "containerExternalIDs CONTAINS %@", folderExternalID)
		let ckQuery = CKQuery(recordType: CloudKitFeed.recordType, predicate: predicate)

		query(ckQuery) { result in
			switch result {
			case .success(let records):
				let feedExternalIds = records.map { $0.externalID }
				completion(.success(feedExternalIds))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func findOrCreateAccount(completion: @escaping (Result<String, Error>) -> Void) {
		let predicate = NSPredicate(format: "isAccount = \"1\"")
		let ckQuery = CKQuery(recordType: CloudKitContainer.recordType, predicate: predicate)

		database?.fetch(withQuery: ckQuery, inZoneWith: zoneID, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { [weak self] result in
			guard let self = self else { return }

			switch result {
			case .success(let (matchResults, _)):
				let records = matchResults.compactMap { try? $0.1.get() }
				DispatchQueue.main.async {
					if !records.isEmpty {
						completion(.success(records[0].externalID))
					} else {
						self.createContainer(name: "Account", isAccount: true, completion: completion)
					}
				}
			case .failure(let error):
				switch CloudKitZoneResult.resolve(error) {
				case .success:
					DispatchQueue.main.async {
						self.createContainer(name: "Account", isAccount: true, completion: completion)
					}
				case .retry(let timeToWait):
					self.retryIfPossible(after: timeToWait) {
						self.findOrCreateAccount(completion: completion)
					}
				case .zoneNotFound, .userDeletedZone:
					self.createZoneRecord() { result in
						switch result {
						case .success:
							self.findOrCreateAccount(completion: completion)
						case .failure(let error):
							DispatchQueue.main.async {
								completion(.failure(CloudKitError(error)))
							}
						}
					}
				default:
					self.createContainer(name: "Account", isAccount: true, completion: completion)
				}
			}
		}

	}

	func createFolder(name: String, completion: @escaping (Result<String, Error>) -> Void) {
		createContainer(name: name, isAccount: false, completion: completion)
	}

	func renameFolder(_ folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = folder.externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: recordID)
		record[CloudKitContainer.Fields.name] = name

		save(record) { result in
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

	func newFeedCKRecord(feedSpecifier: RSOPMLFeedSpecifier, containerExternalID: String) -> CKRecord {
		let record = CKRecord(recordType: CloudKitFeed.recordType, recordID: generateRecordID())
		record[CloudKitFeed.Fields.url] = feedSpecifier.feedURL
		if let editedName = feedSpecifier.title {
			record[CloudKitFeed.Fields.editedName] = editedName
		}
		if let homePageURL = feedSpecifier.homePageURL {
			record[CloudKitFeed.Fields.homePageURL] = homePageURL
		}
		record[CloudKitFeed.Fields.containerExternalIDs] = [containerExternalID]
		return record
	}

	func newContainerCKRecord(name: String) -> CKRecord {
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: generateRecordID())
		record[CloudKitContainer.Fields.name] = name
		record[CloudKitContainer.Fields.isAccount] = "0"
		return record
	}

	func createContainer(name: String, isAccount: Bool, completion: @escaping (Result<String, Error>) -> Void) {
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: generateRecordID())
		record[CloudKitContainer.Fields.name] = name
		record[CloudKitContainer.Fields.isAccount] = isAccount ? "1" : "0"

		save(record) { result in
			switch result {
			case .success:
				completion(.success(record.externalID))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

}
