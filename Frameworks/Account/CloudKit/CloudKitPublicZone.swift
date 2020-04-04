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
	
	struct CloudKitUserWebFeedCheck {
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
	
	func createSubscription(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {
		let webFeedRecordID = CKRecord.ID(recordName: webFeed.url.md5String, zoneID: Self.zoneID)
		let webFeedRecord = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: webFeedRecordID)

		save(webFeedRecord) { result in
			switch result {
			case .success:
				
				let webFeedRecordRef = CKRecord.Reference(recordID: webFeedRecordID, action: .none)
				let predicate = NSPredicate(format: "webFeed = %@", webFeedRecordRef)
				let subscription = CKQuerySubscription(recordType: CloudKitWebFeed.recordType, predicate: predicate, options: [.firesOnRecordUpdate])
				
				let info = CKSubscription.NotificationInfo()
				info.shouldSendContentAvailable = true
				info.desiredKeys = [CloudKitWebFeed.Fields.httpLastModified, CloudKitWebFeed.Fields.httpEtag]
				subscription.notificationInfo = info
				
				self.save(subscription) { result in
					switch result {
					case .success(let subscription):
						
						let userSubscriptionRecord = CKRecord(recordType: CloudKitUserSubscription.recordType, recordID: self.generateRecordID())
						userSubscriptionRecord[CloudKitUserSubscription.Fields.userRecordID] = CloudKitContainer.userRecordID
						userSubscriptionRecord[CloudKitUserSubscription.Fields.webFeed] = webFeedRecordRef
						userSubscriptionRecord[CloudKitUserSubscription.Fields.subscriptionID] = subscription.subscriptionID

						self.save(userSubscriptionRecord, completion: completion)
						
					case .failure(let error):
						completion(.failure(error))
					}
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	/// Remove the subscription for the given feed along with its supporting record
	func removeSubscription(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let userRecordID = CloudKitContainer.userRecordID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}
		
		let webFeedRecordID = CKRecord.ID(recordName: webFeed.url.md5String, zoneID: Self.zoneID)
		let webFeedRecordRef = CKRecord.Reference(recordID: webFeedRecordID, action: .none)
		let predicate = NSPredicate(format: "user = %@ AND webFeed = %@", userRecordID, webFeedRecordRef)
		let ckQuery = CKQuery(recordType: CloudKitUserSubscription.recordType, predicate: predicate)

		query(ckQuery) { result in
			switch result {
			case .success(let records):
				
				if records.count > 0, let subscriptionID = records[0][CloudKitUserSubscription.Fields.subscriptionID] as? String {
					self.delete(subscriptionID: subscriptionID) { result in
						switch result {
						case .success:
							self.delete(recordID: records[0].recordID, completion: completion)
						case .failure(let error):
							completion(.failure(error))
						}
					}
					
				} else {
					completion(.failure(CloudKitZoneError.unknown))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}

	}
	
}
