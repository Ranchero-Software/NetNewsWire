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
	
	/// Create a CloudKit subscription for the webfeed and any other supporting records that we need
	func createSubscription(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {

		func createSubscription(_ webFeedRecordRef: CKRecord.Reference) {
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
					userSubscriptionRecord[CloudKitUserSubscription.Fields.userRecordID] = self.container?.userRecordID
					userSubscriptionRecord[CloudKitUserSubscription.Fields.webFeed] = webFeedRecordRef
					userSubscriptionRecord[CloudKitUserSubscription.Fields.subscriptionID] = subscription.subscriptionID

					self.save(userSubscriptionRecord, completion: completion)
					
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
		
		fetch(externalID: webFeed.url.md5String) { result in
			switch result {
			case .success(let record):
				
				let webFeedRecordRef = CKRecord.Reference(record: record, action: .none)
				createSubscription(webFeedRecordRef)
				
			case .failure:
				
				let webFeedRecordID = CKRecord.ID(recordName: webFeed.url.md5String, zoneID: Self.zoneID)
				let webFeedRecordRef = CKRecord.Reference(recordID: webFeedRecordID, action: .none)
				let webFeedRecord = CKRecord(recordType: CloudKitWebFeed.recordType, recordID: webFeedRecordID)
				webFeedRecord[CloudKitWebFeed.Fields.url] = webFeed.url
				webFeedRecord[CloudKitWebFeed.Fields.httpLastModified] = ""
				webFeedRecord[CloudKitWebFeed.Fields.httpEtag] = ""

				let webFeedCheckRecord = CKRecord(recordType: CloudKitWebFeedCheck.recordType, recordID: self.generateRecordID())
				webFeedRecord[CloudKitWebFeedCheck.Fields.webFeed] = webFeedRecordRef
				webFeedRecord[CloudKitWebFeedCheck.Fields.lastCheck] = Date.distantPast

				self.save([webFeedRecord, webFeedCheckRecord]) { result in
					switch result {
					case .success:
						createSubscription(webFeedRecordRef)
					case .failure(let error):
						completion(.failure(error))
					}
				}
				
			}
		}
		
	}
	
	/// Remove the subscription for the given feed along with its supporting record
	func removeSubscription(_ webFeed: WebFeed, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let userRecordID = self.container?.userRecordID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}
		
		let webFeedRecordID = CKRecord.ID(recordName: webFeed.url.md5String, zoneID: Self.zoneID)
		let webFeedRecordRef = CKRecord.Reference(recordID: webFeedRecordID, action: .none)
		let predicate = NSPredicate(format: "userRecordID = %@ AND webFeed = %@", userRecordID, webFeedRecordRef)
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
					os_log(.error, log: self.log, "Remove subscription error. The subscription wasn't found.")
					completion(.success(()))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}

	}
	
}
