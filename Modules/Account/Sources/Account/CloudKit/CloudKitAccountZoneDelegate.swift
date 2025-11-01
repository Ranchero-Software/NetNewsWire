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
import RSCore
import Articles

final class CloudKitAcountZoneDelegate: CloudKitZoneDelegate {
	
	private typealias UnclaimedWebFeed = (url: URL, name: String?, editedName: String?, homePageURL: String?, webFeedExternalID: String)
	private var newUnclaimedWebFeeds = [String: [UnclaimedWebFeed]]()
	private var existingUnclaimedWebFeeds = [String: [WebFeed]]()

	weak var account: Account?
	weak var articlesZone: CloudKitArticlesZone?

	init(account: Account, articlesZone: CloudKitArticlesZone) {
		self.account = account
		self.articlesZone = articlesZone
	}
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		for deletedRecordKey in deleted {
			switch deletedRecordKey.recordType {
			case CloudKitAccountZone.CloudKitWebFeed.recordType:
				removeWebFeed(deletedRecordKey.recordID.externalID)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				removeContainer(deletedRecordKey.recordID.externalID)
			default:
				assertionFailure("Unknown record type: \(deletedRecordKey.recordType)")
			}
		}
		
		for changedRecord in changed {
			switch changedRecord.recordType {
			case CloudKitAccountZone.CloudKitWebFeed.recordType:
				addOrUpdateWebFeed(changedRecord)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				addOrUpdateContainer(changedRecord)
			default:
				assertionFailure("Unknown record type: \(changedRecord.recordType)")
			}
		}
		
		completion(.success(()))
	}
	
	func addOrUpdateWebFeed(_ record: CKRecord) {
		guard let account = account,
			let urlString = record[CloudKitAccountZone.CloudKitWebFeed.Fields.url] as? String,
			let containerExternalIDs = record[CloudKitAccountZone.CloudKitWebFeed.Fields.containerExternalIDs] as? [String],
			let url = URL(string: urlString) else {
				return
		}
		
		let name = record[CloudKitAccountZone.CloudKitWebFeed.Fields.name] as? String
		let editedName = record[CloudKitAccountZone.CloudKitWebFeed.Fields.editedName] as? String
		let homePageURL = record[CloudKitAccountZone.CloudKitWebFeed.Fields.homePageURL] as? String

		if let webFeed = account.existingWebFeed(withExternalID: record.externalID) {
			updateWebFeed(webFeed, name: name, editedName: editedName, homePageURL: homePageURL, containerExternalIDs: containerExternalIDs)
		} else {
			for containerExternalID in containerExternalIDs {
				if let container = account.existingContainer(withExternalID: containerExternalID) {
					createWebFeedIfNecessary(url: url, name: name, editedName: editedName, homePageURL: homePageURL, webFeedExternalID: record.externalID, container: container)
				} else {
					addNewUnclaimedWebFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, webFeedExternalID: record.externalID, containerExternalID: containerExternalID)
				}
			}
		}
	}
	
	func removeWebFeed(_ externalID: String) {
		if let webFeed = account?.existingWebFeed(withExternalID: externalID), let containers = account?.existingContainers(withWebFeed: webFeed) {
			for container in containers {
				webFeed.dropConditionalGetInfo()
				container.removeWebFeed(webFeed)
			}
		}
	}
	
	func addOrUpdateContainer(_ record: CKRecord) {
		guard let account = account,
			let name = record[CloudKitAccountZone.CloudKitContainer.Fields.name] as? String,
			let isAccount = record[CloudKitAccountZone.CloudKitContainer.Fields.isAccount] as? String,
			isAccount != "1" else {
				return
		}
		
		var folder = account.existingFolder(withExternalID: record.externalID)
		folder?.name = name
		
		if folder == nil {
			folder = account.ensureFolder(with: name)
			folder?.externalID = record.externalID
		}
		
		guard let container = folder, let containerExternalID = container.externalID else { return }
		
		if let newUnclaimedWebFeeds = newUnclaimedWebFeeds[containerExternalID] {
			for newUnclaimedWebFeed in newUnclaimedWebFeeds {
				createWebFeedIfNecessary(url: newUnclaimedWebFeed.url,
										 name: newUnclaimedWebFeed.name,
										 editedName: newUnclaimedWebFeed.editedName,
										 homePageURL: newUnclaimedWebFeed.homePageURL,
										 webFeedExternalID: newUnclaimedWebFeed.webFeedExternalID,
										 container: container)
			}

			self.newUnclaimedWebFeeds.removeValue(forKey: containerExternalID)
		}
		
		if let existingUnclaimedWebFeeds = existingUnclaimedWebFeeds[containerExternalID] {
			for existingUnclaimedWebFeed in existingUnclaimedWebFeeds {
				container.addWebFeed(existingUnclaimedWebFeed)
			}
			self.existingUnclaimedWebFeeds.removeValue(forKey: containerExternalID)
		}
	}
	
	func removeContainer(_ externalID: String) {
		if let folder = account?.existingFolder(withExternalID: externalID) {
			account?.removeFolder(folder)
		}
	}
	
}

private extension CloudKitAcountZoneDelegate {
	
	func updateWebFeed(_ webFeed: WebFeed, name: String?, editedName: String?, homePageURL: String?, containerExternalIDs: [String]) {
		guard let account = account else { return }
		
		webFeed.name = name
		webFeed.editedName = editedName
		webFeed.homePageURL = homePageURL
		
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
				} else {
					addExistingUnclaimedWebFeed(webFeed, containerExternalID: externalID)
				}
			}
		}
	}
	
	func createWebFeedIfNecessary(url: URL, name: String?, editedName: String?, homePageURL: String?, webFeedExternalID: String, container: Container) {
		guard let account = account else { return  }
		
		if account.existingWebFeed(withExternalID: webFeedExternalID) != nil {
			return
		}
		
		let webFeed = account.createWebFeed(with: name, url: url.absoluteString, webFeedID: url.absoluteString, homePageURL: homePageURL)
		webFeed.editedName = editedName
		webFeed.externalID = webFeedExternalID
		container.addWebFeed(webFeed)
	}
	
	func addNewUnclaimedWebFeed(url: URL, name: String?, editedName: String?, homePageURL: String?, webFeedExternalID: String, containerExternalID: String) {
		if var unclaimedWebFeeds = self.newUnclaimedWebFeeds[containerExternalID] {
			unclaimedWebFeeds.append(UnclaimedWebFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, webFeedExternalID: webFeedExternalID))
			self.newUnclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		} else {
			var unclaimedWebFeeds = [UnclaimedWebFeed]()
			unclaimedWebFeeds.append(UnclaimedWebFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, webFeedExternalID: webFeedExternalID))
			self.newUnclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		}
	}
	
	func addExistingUnclaimedWebFeed(_ webFeed: WebFeed, containerExternalID: String) {
		if var unclaimedWebFeeds = self.existingUnclaimedWebFeeds[containerExternalID] {
			unclaimedWebFeeds.append(webFeed)
			self.existingUnclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		} else {
			var unclaimedWebFeeds = [WebFeed]()
			unclaimedWebFeeds.append(webFeed)
			self.existingUnclaimedWebFeeds[containerExternalID] = unclaimedWebFeeds
		}
	}
	
}
