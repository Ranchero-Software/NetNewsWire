//
//  CloudKitAccountZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Web
import Parser
import ParserObjC
import CloudKit
import FoundationExtras
import CloudKitExtras

enum CloudKitAccountZoneError: LocalizedError {
	case unknown
	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor final class CloudKitAccountZone: CloudKitZone {

	let zoneID: CKRecordZone.ID

	let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

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
	
	func importOPML(rootExternalID: String, items: [RSOPMLItem]) async throws {

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

		try await save(records)
	}
    
	///  Persist a web feed record to iCloud and return the external key
	func createFeed(url: String, name: String?, editedName: String?, homePageURL: String?, container: Container) async throws -> String {

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
			throw CloudKitZoneError.corruptAccount
		}
		record[CloudKitFeed.Fields.containerExternalIDs] = [containerExternalID]

		try await save(record)
		return record.externalID
	}
	
	/// Rename the given web feed
	func renameFeed(_ feed: Feed, editedName: String?) async throws {

		guard let externalID = feed.externalID else {
			throw CloudKitZoneError.corruptAccount
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitFeed.recordType, recordID: recordID)
		record[CloudKitFeed.Fields.editedName] = editedName
		
		try await save(record)
	}
	
	/// Removes a web feed from a container and optionally deletes it, returning true if deleted
	@discardableResult
	func removeFeed(_ feed: Feed, from: Container) async throws -> Bool {

		guard let fromContainerExternalID = from.externalID else {
			throw CloudKitZoneError.corruptAccount
		}

		do {
			let record = try await fetch(externalID: feed.externalID)

			if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {

				var containerExternalIDSet = Set(containerExternalIDs)
				containerExternalIDSet.remove(fromContainerExternalID)

				if containerExternalIDSet.isEmpty {
					try await delete(externalID: feed.externalID)
					return true
				} else {
					record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
					try await save(record)
					return false
				}
			}
			
			return false
		} catch {
			if let ckError = ((error as? CloudKitError)?.error as? CKError), ckError.code == .unknownItem {
				return true
			} else {
				throw error
			}
		}
	}
	
	func moveFeed(_ feed: Feed, from: Container, to: Container) async throws {

		guard let fromContainerExternalID = from.externalID, let toContainerExternalID = to.externalID else {
			throw CloudKitZoneError.corruptAccount
		}

		let record = try await fetch(externalID: feed.externalID)

		if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
			var containerExternalIDSet = Set(containerExternalIDs)
			containerExternalIDSet.remove(fromContainerExternalID)
			containerExternalIDSet.insert(toContainerExternalID)
			record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
			try await save(record)
		}
	}

	func addFeed(_ feed: Feed, to: Container) async throws {

		guard let toContainerExternalID = to.externalID else {
			throw CloudKitZoneError.corruptAccount
		}

		let record = try await fetch(externalID: feed.externalID)

		if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
			var containerExternalIDSet = Set(containerExternalIDs)
			containerExternalIDSet.insert(toContainerExternalID)
			record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
			try await save(record)
		}
	}

	func findFeedExternalIDs(for folder: Folder) async throws -> [String] {

		guard let folderExternalID = folder.externalID else {
			throw CloudKitAccountZoneError.unknown
		}

		let predicate = NSPredicate(format: "containerExternalIDs CONTAINS %@", folderExternalID)
		let ckQuery = CKQuery(recordType: CloudKitFeed.recordType, predicate: predicate)

		let records = try await query(ckQuery)

		let feedExternalIDs = records.map { $0.externalID }
		return feedExternalIDs
	}

	func findOrCreateAccount() async throws -> String {

		guard let database else {
			throw CloudKitAccountZoneError.unknown
		}

		let predicate = NSPredicate(format: "isAccount = \"1\"")
		let ckQuery = CKQuery(recordType: CloudKitContainer.recordType, predicate: predicate)

		do {
			let records = try await database.perform(ckQuery, inZoneWith: zoneID)
			if records.count > 0 {
				return records[0].externalID
			} else {
				return try await createContainer(name: "Account", isAccount: true)
			}

		} catch {

			switch CloudKitZoneResult.resolve(error) {

			case .retry(let timeToWait):
				await delay(for: timeToWait)
				return try await findOrCreateAccount()

			case .zoneNotFound, .userDeletedZone:
				_ = try await createZoneRecord()
				return try await findOrCreateAccount()

			default:
				return try await createContainer(name: "Account", isAccount: true)
			}
		}
	}
	
	func createFolder(name: String) async throws -> String {

		return try await createContainer(name: name, isAccount: false)
	}
	
	func renameFolder(_ folder: Folder, to name: String) async throws {

		guard let externalID = folder.externalID else {
			throw CloudKitZoneError.corruptAccount
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: recordID)
		record[CloudKitContainer.Fields.name] = name

		try await save(record)
	}
	
	func removeFolder(_ folder: Folder) async throws {

		try await delete(externalID: folder.externalID)
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
	
	func createContainer(name: String, isAccount: Bool) async throws -> String {

		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: generateRecordID())
		record[CloudKitContainer.Fields.name] = name
		record[CloudKitContainer.Fields.isAccount] = isAccount ? "1" : "0"

		try await save(record)
		return record.externalID
	}
}
