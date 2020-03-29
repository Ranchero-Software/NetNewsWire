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

	func addOrUpdateWebFeed(_ record: CKRecord) {
		guard let account = account else { return }
		
		let editedName = record[CloudKitAccountZone.CloudKitWebFeed.Fields.editedName] as? String
		
		if let webFeed = account.existingWebFeed(withExternalID: record.externalID) {
			webFeed.editedName = editedName
		} else {
			if let urlString = record[CloudKitAccountZone.CloudKitWebFeed.Fields.url] as? String, let url = URL(string: urlString) {
				downloadAndAddWebFeed(url: url, editedName: editedName, externalID: record.externalID)
			} else {
				os_log(.error, log: self.log, "Failed to add or update web feed.")
			}
		}
	}
	
	func removeWebFeed(_ externalID: String) {
		if let webFeed = account?.existingWebFeed(withExternalID: externalID) {
			account?.removeWebFeed(webFeed)
		}
	}
	
}

private extension CloudKitAcountZoneDelegate {
	
	func downloadAndAddWebFeed(url: URL, editedName: String?, externalID: String) {
		guard let account = account else { return }
		
		let webFeed = account.createWebFeed(with: editedName, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: nil)
		webFeed.editedName = editedName
		webFeed.externalID = externalID
		account.addWebFeed(webFeed)
		
		refreshProgress?.addToNumberOfTasksAndRemaining(1)
		InitialFeedDownloader.download(url) { parsedFeed in
			self.refreshProgress?.completeTask()
			if let parsedFeed = parsedFeed {
				account.update(webFeed, with: parsedFeed, {_ in })
			}
		}

	}
	
}
