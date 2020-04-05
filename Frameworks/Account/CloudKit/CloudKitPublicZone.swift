//
//  CloudKitPublicZone.swift
//  Account
//
//  Created by Maurice Parker on 4/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import os.log

final class CloudKitPublicZone: CloudKitZone {
	
	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.default().zoneID
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?
	
	struct CloudKitWebFeed {
		static let recordType = "WebFeed"
		struct Fields {
			static let url = "url"
			static let httpLastModified = "httpLastModified"
			static let httpEtag = "httpEtag"
		}
	}
	
	struct CloudKitWebFeedCheck {
		static let recordType = "WebFeedCheck"
		struct Fields {
			static let webFeed = "webFeed"
			static let lastCheck = "lastCheck"
		}
	}
	
	struct CloudKitUserSubscription {
		static let recordType = "UserSubscription"
		struct Fields {
			static let userRecordID = "userRecordID"
			static let webFeed = "webFeed"
			static let subscriptionID = "subscriptionID"
		}
	}
	
	init(container: CKContainer) {
		self.container = container
		self.database = container.publicCloudDatabase
	}

	func subscribeToZoneChanges() {}
	
	func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		completion()
	}
	
	/// Create any new subscriptions and delete any old ones
	func manageSubscriptions(_ webFeedURLs: Set<String>, completion: @escaping (Result<Void, Error>) -> Void) {
		
		var webFeedRecords = [CKRecord]()
		for webFeedURL in webFeedURLs {
			let webFeedRecordID = CKRecord.ID(recordName: webFeedURL.md5String, zoneID: Self.zoneID)
			let webFeedRecord = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: webFeedRecordID)
			webFeedRecord[CloudKitWebFeed.Fields.url] = webFeedURL
			webFeedRecord[CloudKitWebFeed.Fields.httpLastModified] = ""
			webFeedRecord[CloudKitWebFeed.Fields.httpEtag] = ""
			webFeedRecords.append(webFeedRecord)
		}

		self.saveIfNew(webFeedRecords) { _ in
				
			var subscriptions = [CKSubscription]()
			let webFeedURLChunks = Array(webFeedURLs).chunked(into: 20)
			for webFeedURLChunk in webFeedURLChunks {
			
				let predicate = NSPredicate(format: "url in %@", webFeedURLChunk)
				let subscription = CKQuerySubscription(recordType: CloudKitWebFeed.recordType, predicate: predicate, options: [.firesOnRecordUpdate])
				let info = CKSubscription.NotificationInfo()
				info.shouldSendContentAvailable = true
				info.desiredKeys = [CloudKitWebFeed.Fields.httpLastModified, CloudKitWebFeed.Fields.httpEtag]
				subscription.notificationInfo = info
				subscriptions.append(subscription)
				
			}
			
			self.fetchAllUserSubscriptions() { result in
				switch result {
				case .success(let subscriptionsToDelete):
					let subscriptionToDeleteIDs = subscriptionsToDelete.map({ $0.subscriptionID })
					self.modify(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: subscriptionToDeleteIDs, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
			
		}
		
	}
	
}
