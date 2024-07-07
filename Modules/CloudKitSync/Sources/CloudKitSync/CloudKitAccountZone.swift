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

enum CloudKitAccountZoneError: LocalizedError {
	case unknown
	var errorDescription: String? {
		return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
	}
}

@MainActor public final class CloudKitAccountZone: CloudKitZone {

	public let zoneID: CKRecordZone.ID

	public let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	public weak var container: CKContainer?
	public weak var database: CKDatabase?
	public var delegate: CloudKitZoneDelegate?

	public struct CloudKitFeed {
		public static let recordType = "AccountWebFeed"
		public struct Fields {
			public static let url = "url"
			public static let name = "name"
			public static let editedName = "editedName"
			public static let homePageURL = "homePageURL"
			public static let containerExternalIDs = "containerExternalIDs"
		}
	}
	
	public struct CloudKitContainer {
		public static let recordType = "AccountContainer"
		public struct Fields {
			public static let isAccount = "isAccount"
			public static let name = "name"
		}
	}
	
	public init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
		self.zoneID = CKRecordZone.ID(zoneName: "Account", ownerName: CKCurrentUserDefaultName)
		migrateChangeToken()
    }
	
	public func importOPML(rootExternalID: String, items: [RSOPMLItem]) async throws {

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
	public func createFeed(url: String, name: String?, editedName: String?, homePageURL: String?, containerExternalID: String) async throws -> String {

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

		record[CloudKitFeed.Fields.containerExternalIDs] = [containerExternalID]

		try await save(record)
		return record.externalID
	}
	
	/// Rename the given web feed
	public func renameFeed(externalID: String, editedName: String?) async throws {

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitFeed.recordType, recordID: recordID)
		record[CloudKitFeed.Fields.editedName] = editedName
		
		try await save(record)
	}
	
	/// Removes a web feed from a container and optionally deletes it, returning true if deleted
	@discardableResult
	public func removeFeed(externalID: String, from containerExternalID: String) async throws -> Bool {

		do {
			let record = try await fetch(externalID: externalID)

			if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {

				var containerExternalIDSet = Set(containerExternalIDs)
				containerExternalIDSet.remove(containerExternalID)

				if containerExternalIDSet.isEmpty {
					try await delete(externalID: externalID)
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
	
	public func moveFeed(externalID: String, from sourceContainerExternalID: String, to destinationContainerExternalID: String) async throws {

		let record = try await fetch(externalID: externalID)

		if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
			var containerExternalIDSet = Set(containerExternalIDs)
			containerExternalIDSet.remove(sourceContainerExternalID)
			containerExternalIDSet.insert(destinationContainerExternalID)
			record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
			try await save(record)
		}
	}

	public func addFeed(externalID: String, to containerExternalID: String) async throws {

		let record = try await fetch(externalID: externalID)

		if let containerExternalIDs = record[CloudKitFeed.Fields.containerExternalIDs] as? [String] {
			var containerExternalIDSet = Set(containerExternalIDs)
			containerExternalIDSet.insert(containerExternalID)
			record[CloudKitFeed.Fields.containerExternalIDs] = Array(containerExternalIDSet)
			try await save(record)
		}
	}

	public func findFeedExternalIDs(for folderExternalID: String) async throws -> [String] {

		let predicate = NSPredicate(format: "containerExternalIDs CONTAINS %@", folderExternalID)
		let ckQuery = CKQuery(recordType: CloudKitFeed.recordType, predicate: predicate)

		let records = try await query(ckQuery)

		let feedExternalIDs = records.map { $0.externalID }
		return feedExternalIDs
	}

	public func findOrCreateAccount() async throws -> String {

		try await withCheckedThrowingContinuation { continuation in

			self.findOrCreateAccount { result in
				switch result {
				case .success(let externalID):
					continuation.resume(returning: externalID)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func findOrCreateAccount(completion: @escaping @Sendable (Result<String, Error>) -> Void) {

		guard let database else {
			completion(.failure(CloudKitAccountZoneError.unknown))
			return
		}

		let predicate = NSPredicate(format: "isAccount = \"1\"")
		let ckQuery = CKQuery(recordType: CloudKitContainer.recordType, predicate: predicate)

		database.fetch(withQuery: ckQuery, inZoneWith: zoneID) { result in

			switch result {

			case .success((let matchResults, _)):

				for result in matchResults {
					let (_, recordResult) = result
					switch recordResult {

					case .success(let record):
						completion(.success(record.externalID))
						return

					case .failure(_):
						continue
					}
				}

				// If no records in matchResults
				completion(.failure(CloudKitAccountZoneError.unknown))

			case .failure(let error):

				switch CloudKitZoneResult.resolve(error) {

				case .retry(let timeToWait):
					self.retryIfPossible(after: timeToWait) {
						self.findOrCreateAccount(completion: completion)
					}

				case .zoneNotFound, .userDeletedZone:
					Task { @MainActor in
						_ = try await self.createZoneRecord()
						self.findOrCreateAccount(completion: completion)
					}

				default:
					Task { @MainActor in

						do {
							let externalID = try await self.createContainer(name: "Account", isAccount: true)
							completion(.success(externalID))
						} catch {
							completion(.failure(error))
						}
					}
				}
			}
		}
	}

	public func createFolder(name: String) async throws -> String {

		return try await createContainer(name: name, isAccount: false)
	}
	
	public func renameFolder(externalID: String, to name: String) async throws {

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		let record = CKRecord(recordType: CloudKitContainer.recordType, recordID: recordID)
		record[CloudKitContainer.Fields.name] = name

		try await save(record)
	}
	
	public func removeFolder(externalID: String) async throws {

		try await delete(externalID: externalID)
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
