//
//  CloudKitArticlesZoneDelegate.swift
//  Account
//
//  Created by Maurice Parker on 4/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import CloudKit
import SyncDatabase

class CloudKitArticlesZoneDelegate: CloudKitZoneDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var account: Account?
	var database: SyncDatabase
	
	init(account: Account, database: SyncDatabase) {
		self.account = account
		self.database = database
	}
	
	func cloudKitDidChange(record: CKRecord) {
		// Process everything in the batch method
	}
	
	func cloudKitDidDelete(recordKey: CloudKitRecordKey) {
		// Article downloads clean up old articles and statuses
	}
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void) {
		
		database.selectPendingReadStatusArticleIDs() { result in
			switch result {
			case .success(let pendingReadStatusArticleIDs):

				self.database.selectPendingStarredStatusArticleIDs() { result in
					switch result {
					case .success(let pendingStarredStatusArticleIDs):
						
						self.process(records: changed,
									 pendingReadStatusArticleIDs: pendingReadStatusArticleIDs,
									 pendingStarredStatusArticleIDs: pendingStarredStatusArticleIDs,
									 completion: completion)
						
					case .failure(let error):
						os_log(.error, log: self.log, "Error occurred geting pending starred records: %@", error.localizedDescription)
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Error occurred getting pending read status records: %@", error.localizedDescription)
			}

		}
		
	}
	
}

private extension CloudKitArticlesZoneDelegate {
	
	func process(records: [CKRecord], pendingReadStatusArticleIDs: Set<String>, pendingStarredStatusArticleIDs: Set<String>, completion: @escaping (Result<Void, Error>) -> Void) {
		
		let receivedUnreadArticleIDs = Set(records.filter( { $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "0" }).map({ $0.externalID }))
		let receivedReadArticleIDs =  Set(records.filter( { $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.read] == "1" }).map({ $0.externalID }))
		let receivedUnstarredArticleIDs =  Set(records.filter( { $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "0" }).map({ $0.externalID }))
		let receivedStarredArticleIDs =  Set(records.filter( { $0[CloudKitArticlesZone.CloudKitArticleStatus.Fields.starred] == "1" }).map({ $0.externalID }))

		let updateableUnreadArticleIDs = receivedUnreadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableReadArticleIDs = receivedReadArticleIDs.subtracting(pendingReadStatusArticleIDs)
		let updateableUnstarredArticleIDs = receivedUnstarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)
		let updateableStarredArticleIDs = receivedStarredArticleIDs.subtracting(pendingStarredStatusArticleIDs)

		let group = DispatchGroup()
		
		group.enter()
		account?.markAsUnread(updateableUnreadArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsRead(updateableReadArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsUnstarred(updateableUnstarredArticleIDs) { _ in
			group.leave()
		}
		
		group.enter()
		account?.markAsStarred(updateableStarredArticleIDs) { _ in
			group.leave()
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
		
	}
	
}
