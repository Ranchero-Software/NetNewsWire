//
//  CloudKitAccountZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 3/29/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import CloudKit

class CloudKitAcountZoneDelegate: CloudKitZoneDelegate {
	
	private typealias UnclaimedWebFeed = (url: String, editedName: String?)
	private var unclaimedWebFeeds = [String: UnclaimedWebFeed]()
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	weak var account: Account?
	weak var refreshProgress: DownloadProgress?
	
	init(account: Account, refreshProgress: DownloadProgress) {
		self.account = account
		self.refreshProgress = refreshProgress
	}
	
	func cloudKitDidChange(record: CKRecord) {
		switch record.recordType {
		case CloudKitAccountZone.CloudKitWebFeed.recordType:
			addOrUpdateWebFeed(record)
		case CloudKitAccountZone.CloudKitContainer.recordType:
			addOrUpdateContainer(record)
		case CloudKitAccountZone.CloudKitContainerWebFeed.recordType:
			addOrUpdateContainerWebFeed(record)
		default:
			assertionFailure("Unknown record type: \(record.recordType)")
		}
	}
	
	func cloudKitDidDelete(recordType: CKRecord.RecordType, recordID: CKRecord.ID) {
		switch recordType {
		case CloudKitAccountZone.CloudKitWebFeed.recordType:
			break
		case CloudKitAccountZone.CloudKitContainer.recordType:
			removeContainer(recordID.externalID)
		case CloudKitAccountZone.CloudKitContainerWebFeed.recordType:
			removeContainerWebFeed(recordID.externalID)
		default:
			assertionFailure("Unknown record type: \(recordID.externalID)")
		}
	}

	func addOrUpdateWebFeed(_ record: CKRecord) {
		guard let account = account else { return }
		
		let editedName = record[CloudKitAccountZone.CloudKitWebFeed.Fields.editedName] as? String
		
		if let webFeed = account.existingWebFeed(withExternalID: record.externalID) {
			webFeed.editedName = editedName
		} else {
			if let urlString = record[CloudKitAccountZone.CloudKitWebFeed.Fields.url] as? String {
				unclaimedWebFeeds[record.externalID] = UnclaimedWebFeed(url: urlString, editedName: editedName)
			}
		}
	}
	
	func addOrUpdateContainer(_ record: CKRecord) {
		guard let account = account,
			let name = record[CloudKitAccountZone.CloudKitContainer.Fields.name] as? String,
			let isAccount = record[CloudKitAccountZone.CloudKitContainer.Fields.isAccount] as? String,
			isAccount != "true" else { return }
		
		if let folder = account.existingFolder(withExternalID: record.externalID) {
			folder.name = name
		} else {
			let folder = account.ensureFolder(with: name)
			folder?.externalID = record.externalID
		}
	}
	
	func removeContainer(_ externalID: String) {
		if let folder = account?.existingFolder(withExternalID: externalID) {
			account?.removeFolder(folder)
		}
	}
	
	func addOrUpdateContainerWebFeed(_ record: CKRecord) {
		guard let account = account,
			let containerReference = record[CloudKitAccountZone.CloudKitContainerWebFeed.Fields.container] as? CKRecord.Reference,
			let webFeedReference = record[CloudKitAccountZone.CloudKitContainerWebFeed.Fields.webFeed] as? CKRecord.Reference else { return }
		
		let containerWebFeedExternalID = record.externalID
		let containerExternalID = containerReference.recordID.externalID
		let webFeedExternalID = webFeedReference.recordID.externalID
		
		guard let container = account.existingContainer(withExternalID: containerExternalID) else { return }
		
		if let webFeed = account.existingWebFeed(withExternalID: webFeedExternalID) {
			webFeed.folderRelationship?[containerWebFeedExternalID] = containerExternalID
			container.addWebFeed(webFeed)
			return
		}
		
		guard let unclaimedWebFeed = unclaimedWebFeeds[webFeedExternalID] else { return }
		unclaimedWebFeeds.removeValue(forKey: webFeedExternalID)
		
		let webFeed = account.createWebFeed(with: nil, url: unclaimedWebFeed.url, webFeedID: unclaimedWebFeed.url, homePageURL: nil)
		webFeed.editedName = unclaimedWebFeed.editedName
		webFeed.externalID = webFeedExternalID
		webFeed.folderRelationship = [String: String]()
		webFeed.folderRelationship![containerWebFeedExternalID] = containerExternalID
		container.addWebFeed(webFeed)
		
		guard let url = URL(string: unclaimedWebFeed.url) else { return }
		
		refreshProgress?.addToNumberOfTasksAndRemaining(1)
		InitialFeedDownloader.download(url) { parsedFeed in
			self.refreshProgress?.completeTask()
			if let parsedFeed = parsedFeed {
				account.update(webFeed, with: parsedFeed, {_ in })
			}
		}
	}
	
	func removeContainerWebFeed(_ containerWebFeedExternalID: String) {
		guard let account = account,
			let webFeed = account.flattenedWebFeeds().first(where: { $0.folderRelationship?.keys.contains(containerWebFeedExternalID) ?? false }),
			let containerExternalId = webFeed.folderRelationship?[containerWebFeedExternalID] else { return }
		
		webFeed.folderRelationship?.removeValue(forKey: containerWebFeedExternalID)

		guard account.externalID != containerExternalId else {
			account.removeWebFeed(webFeed)
			return
		}
		
		guard let folder = account.existingFolder(withExternalID: containerExternalId) else { return }
		folder.removeWebFeed(webFeed)
	}
	
}
