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
	
	private typealias UnclaimedWebFeed = (url: URL, editedName: String?, webFeedExternalID: String)
	private var unclaimedWebFeeds = [String: [UnclaimedWebFeed]]()
	
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
		default:
			assertionFailure("Unknown record type: \(record.recordType)")
		}
	}
	
	func cloudKitDidDelete(recordKey: CloudKitRecordKey) {
		switch recordKey.recordType {
		case CloudKitAccountZone.CloudKitWebFeed.recordType:
			removeWebFeed(recordKey.recordID.externalID)
		case CloudKitAccountZone.CloudKitContainer.recordType:
			removeContainer(recordKey.recordID.externalID)
		default:
			assertionFailure("Unknown record type: \(recordKey.recordType)")
		}
	}
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		completion(.success(()))
	}
	
	func addOrUpdateWebFeed(_ record: CKRecord) {
		guard let account = account,
			let urlString = record[CloudKitAccountZone.CloudKitWebFeed.Fields.url] as? String,
			let containerExternalIDs = record[CloudKitAccountZone.CloudKitWebFeed.Fields.containerExternalIDs] as? [String],
			let url = URL(string: urlString) else { return }
		
		let editedName = record[CloudKitAccountZone.CloudKitWebFeed.Fields.editedName] as? String
		
		if let webFeed = account.existingWebFeed(withExternalID: record.externalID) {
			updateWebFeed(webFeed, editedName: editedName, containerExternalIDs: containerExternalIDs)
		} else {
			var webFeed: WebFeed? = nil
			for containerExternalID in containerExternalIDs {
				if let container = account.existingContainer(withExternalID: containerExternalID) {
					if webFeed == nil {
						webFeed = createWebFeed(url: url, editedName: editedName, webFeedExternalID: record.externalID)
					}
					container.addWebFeed(webFeed!)
				} else {
					addUnclaimedWebFeed(url: url, editedName: editedName, webFeedExternalID: record.externalID, containerExternalID: containerExternalID)
				}
			}
		}
	}
	
	func removeWebFeed(_ externalID: String) {
		if let webFeed = account?.existingWebFeed(withExternalID: externalID), let containers = account?.existingContainers(withWebFeed: webFeed) {
			containers.forEach { $0.removeWebFeed(webFeed) }
		}
	}
	
	func addOrUpdateContainer(_ record: CKRecord) {
		guard let account = account,
			let name = record[CloudKitAccountZone.CloudKitContainer.Fields.name] as? String,
			let isAccount = record[CloudKitAccountZone.CloudKitContainer.Fields.isAccount] as? String,
			isAccount != "1" else { return }
		
		var folder = account.existingFolder(withExternalID: record.externalID)
		folder?.name = name
		
		if folder == nil {
			folder = account.ensureFolder(with: name)
			folder?.externalID = record.externalID
		}
		
		if let folder = folder, let containerExternalID = folder.externalID, let unclaimedWebFeeds = unclaimedWebFeeds[containerExternalID] {
			for unclaimedWebFeed in unclaimedWebFeeds {
				var webFeed = account.existingWebFeed(withExternalID: unclaimedWebFeed.webFeedExternalID)
				if webFeed == nil {
					webFeed = createWebFeed(url: unclaimedWebFeed.url, editedName: unclaimedWebFeed.editedName, webFeedExternalID: unclaimedWebFeed.webFeedExternalID)
				}
				if let webFeed = webFeed {
					folder.addWebFeed(webFeed)
				}
			}
			self.unclaimedWebFeeds.removeValue(forKey: containerExternalID)
		}
	}
	
	func removeContainer(_ externalID: String) {
		if let folder = account?.existingFolder(withExternalID: externalID) {
			account?.removeFolder(folder)
		}
	}
	
}

private extension CloudKitAcountZoneDelegate {
	
	func updateWebFeed(_ webFeed: WebFeed, editedName: String?, containerExternalIDs: [String]) {
		guard let account = account else { return }
		webFeed.editedName = editedName
		
		let existingContainers = account.existingContainers(withWebFeed: webFeed)
		let existingContainerExternalIds = existingContainers.compactMap { $0.externalID }

		let diff = containerExternalIDs.difference(from: existingContainerExternalIds)
		
		for change in diff {
			switch change {
			case .remove(_, let externalID, _):
				if let container = existingContainers.first(where: { $0.externalID == externalID }) {
					container.removeWebFeed(webFeed)
				}
			case .insert(_, let externalID, _):
				if let container = account.existingContainer(withExternalID: externalID) {
					container.addWebFeed(webFeed)
				}
			}
		}
	}
	
	func createWebFeed(url: URL, editedName: String?, webFeedExternalID: String) -> WebFeed? {
		guard let account = account else { return nil }
		
		let webFeed = account.createWebFeed(with: editedName, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
		webFeed.editedName = editedName
		webFeed.externalID = webFeedExternalID
		
		refreshProgress?.addToNumberOfTasksAndRemaining(1)
		InitialFeedDownloader.download(url) { parsedFeed in
			self.refreshProgress?.completeTask()
			if let parsedFeed = parsedFeed {
				account.update(webFeed, with: parsedFeed, {_ in })
			}
		}

		return webFeed
	}
	
	func addUnclaimedWebFeed(url: URL, editedName: String?, webFeedExternalID: String, containerExternalID: String) {
		if var unclaimedWebFeeds = self.unclaimedWebFeeds[containerExternalID] {
			unclaimedWebFeeds.append(UnclaimedWebFeed(url: url, editedName: editedName, webFeedExternalID: webFeedExternalID))
			self.unclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		} else {
			var unclaimedWebFeeds = [UnclaimedWebFeed]()
			unclaimedWebFeeds.append(UnclaimedWebFeed(url: url, editedName: editedName, webFeedExternalID: webFeedExternalID))
			self.unclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		}
	}
	
}
