//
//  CloudKitAccountZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

final class CloudKitAccountZone: CloudKitZone {

	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.ID(zoneName: "Account", ownerName: CKCurrentUserDefaultName)
	}
	
    let container: CKContainer
    let database: CKDatabase
    
    init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
    }
    
	///  Persist a feed record to iCloud and return the external key
	func createFeed(url: String, editedName: String?, completion: @escaping (Result<String, Error>) -> Void) {
		let record = CKRecord(recordType: "Feed", recordID: generateRecordID())
		record["url"] = url
		if let editedName = editedName {
			record["editedName"] = editedName
		}
		
		modify(recordsToStore: [record], recordIDsToDelete: []) { result in
			switch result {
			case .success:
				completion(.success(record.recordID.recordName))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
//    private func fetchChangesInZones(_ callback: ((Error?) -> Void)? = nil) {
//        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: zoneIdOptions)
//        changesOp.fetchAllChanges = true
//
//        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneId, token, _ in
//            guard let self = self else { return }
//            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
//            syncObject.zoneChangesToken = token
//        }
//
//        changesOp.recordChangedBlock = { [weak self] record in
//            /// The Cloud will return the modified record since the last zoneChangesToken, we need to do local cache here.
//            /// Handle the record:
//            guard let self = self else { return }
//            guard let syncObject = self.syncObjects.first(where: { $0.recordType == record.recordType }) else { return }
//            syncObject.add(record: record)
//        }
//
//        changesOp.recordWithIDWasDeletedBlock = { [weak self] recordId, _ in
//            guard let self = self else { return }
//            guard let syncObject = self.syncObjects.first(where: { $0.zoneID == recordId.zoneID }) else { return }
//            syncObject.delete(recordID: recordId)
//        }
//
//        changesOp.recordZoneFetchCompletionBlock = { [weak self](zoneId ,token, _, _, error) in
//            guard let self = self else { return }
//            switch ErrorHandler.shared.resultType(with: error) {
//            case .success:
//                guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
//                syncObject.zoneChangesToken = token
//            case .retry(let timeToWait, _):
//                ErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
//                    self.fetchChangesInZones(callback)
//                })
//            case .recoverableError(let reason, _):
//                switch reason {
//                case .changeTokenExpired:
//                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
//                    guard let syncObject = self.syncObjects.first(where: { $0.zoneID == zoneId }) else { return }
//                    syncObject.zoneChangesToken = nil
//                    self.fetchChangesInZones(callback)
//                default:
//                    return
//                }
//            default:
//                return
//            }
//        }
//
//        changesOp.fetchRecordZoneChangesCompletionBlock = { error in
//            callback?(error)
//        }
//
//        database.add(changesOp)
//    }
	
}
