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

	private typealias UnclaimedFeed = (url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String)
	private var newUnclaimedFeeds = [String: [UnclaimedFeed]]()
	private var existingUnclaimedFeeds = [String: [Feed]]()

	weak var account: Account?
	weak var articlesZone: CloudKitArticlesZone?

	init(account: Account, articlesZone: CloudKitArticlesZone) {
		self.account = account
		self.articlesZone = articlesZone
	}

	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		for deletedRecordKey in deleted {
			switch deletedRecordKey.recordType {
			case CloudKitAccountZone.CloudKitFeed.recordType:
				removeFeed(deletedRecordKey.recordID.externalID)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				removeContainer(deletedRecordKey.recordID.externalID)
			default:
				assertionFailure("Unknown record type: \(deletedRecordKey.recordType)")
			}
		}

		for changedRecord in changed {
			switch changedRecord.recordType {
			case CloudKitAccountZone.CloudKitFeed.recordType:
				addOrUpdateFeed(changedRecord)
			case CloudKitAccountZone.CloudKitContainer.recordType:
				addOrUpdateContainer(changedRecord)
			default:
				assertionFailure("Unknown record type: \(changedRecord.recordType)")
			}
		}

		completion(.success(()))
	}

	func addOrUpdateFeed(_ record: CKRecord) {
		guard let account = account,
			let urlString = record[CloudKitAccountZone.CloudKitFeed.Fields.url] as? String,
			let containerExternalIDs = record[CloudKitAccountZone.CloudKitFeed.Fields.containerExternalIDs] as? [String],
			let url = URL(string: urlString) else {
				return
		}

		let name = record[CloudKitAccountZone.CloudKitFeed.Fields.name] as? String
		let editedName = record[CloudKitAccountZone.CloudKitFeed.Fields.editedName] as? String
		let homePageURL = record[CloudKitAccountZone.CloudKitFeed.Fields.homePageURL] as? String

		if let feed = account.existingFeed(withExternalID: record.externalID) {
			updateFeed(feed, name: name, editedName: editedName, homePageURL: homePageURL, containerExternalIDs: containerExternalIDs)
		} else {
			for containerExternalID in containerExternalIDs {
				if let container = account.existingContainer(withExternalID: containerExternalID) {
					createFeedIfNecessary(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: record.externalID, container: container)
				} else {
					addNewUnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: record.externalID, containerExternalID: containerExternalID)
				}
			}
		}
	}

	func removeFeed(_ externalID: String) {
		if let feed = account?.existingFeed(withExternalID: externalID), let containers = account?.existingContainers(withFeed: feed) {
			for container in containers {
				feed.dropConditionalGetInfo()
				container.removeFeed(feed)
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

		if let newUnclaimedFeeds = newUnclaimedFeeds[containerExternalID] {
			for newUnclaimedFeed in newUnclaimedFeeds {
				createFeedIfNecessary(url: newUnclaimedFeed.url,
										 name: newUnclaimedFeed.name,
										 editedName: newUnclaimedFeed.editedName,
										 homePageURL: newUnclaimedFeed.homePageURL,
										 feedExternalID: newUnclaimedFeed.feedExternalID,
										 container: container)
			}

			self.newUnclaimedFeeds.removeValue(forKey: containerExternalID)
		}

		if let existingUnclaimedFeeds = existingUnclaimedFeeds[containerExternalID] {
			for existingUnclaimedFeed in existingUnclaimedFeeds {
				container.addFeed(existingUnclaimedFeed)
			}
			self.existingUnclaimedFeeds.removeValue(forKey: containerExternalID)
		}
	}

	func removeContainer(_ externalID: String) {
		if let folder = account?.existingFolder(withExternalID: externalID) {
			account?.removeFolder(folder)
		}
	}

}

private extension CloudKitAcountZoneDelegate {

	func updateFeed(_ feed: Feed, name: String?, editedName: String?, homePageURL: String?, containerExternalIDs: [String]) {
		guard let account = account else { return }

		feed.name = name
		feed.editedName = editedName
		feed.homePageURL = homePageURL

		let existingContainers = account.existingContainers(withFeed: feed)
		let existingContainerExternalIds = existingContainers.compactMap { $0.externalID }

		let diff = containerExternalIDs.difference(from: existingContainerExternalIds)

		for change in diff {
			switch change {
			case .remove(_, let externalID, _):
				if let container = existingContainers.first(where: { $0.externalID == externalID }) {
					container.removeFeed(feed)
				}
			case .insert(_, let externalID, _):
				if let container = account.existingContainer(withExternalID: externalID) {
					container.addFeed(feed)
				} else {
					addExistingUnclaimedFeed(feed, containerExternalID: externalID)
				}
			}
		}
	}

	func createFeedIfNecessary(url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String, container: Container) {
		guard let account = account else { return  }

		if account.existingFeed(withExternalID: feedExternalID) != nil {
			return
		}

		let feed = account.createFeed(with: name, url: url.absoluteString, feedID: url.absoluteString, homePageURL: homePageURL)
		feed.editedName = editedName
		feed.externalID = feedExternalID
		container.addFeed(feed)
	}

	func addNewUnclaimedFeed(url: URL, name: String?, editedName: String?, homePageURL: String?, feedExternalID: String, containerExternalID: String) {
		if var unclaimedFeeds = self.newUnclaimedFeeds[containerExternalID] {
			unclaimedFeeds.append(UnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: feedExternalID))
			self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		} else {
			var unclaimedFeeds = [UnclaimedFeed]()
			unclaimedFeeds.append(UnclaimedFeed(url: url, name: name, editedName: editedName, homePageURL: homePageURL, feedExternalID: feedExternalID))
			self.newUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		}
	}

	func addExistingUnclaimedFeed(_ feed: Feed, containerExternalID: String) {
		if var unclaimedFeeds = self.existingUnclaimedFeeds[containerExternalID] {
			unclaimedFeeds.append(feed)
			self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		} else {
			var unclaimedFeeds = [Feed]()
			unclaimedFeeds.append(feed)
			self.existingUnclaimedFeeds[containerExternalID] = unclaimedFeeds
		}
	}

}
