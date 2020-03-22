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
    

	
//    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?) {
//        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
//
//        /// Only update the changeToken when fetch process completes
//        changesOperation.changeTokenUpdatedBlock = { [weak self] newToken in
//            self?.databaseChangeToken = newToken
//        }
//
//        changesOperation.fetchDatabaseChangesCompletionBlock = {
//            [weak self]
//            newToken, _, error in
//            guard let self = self else { return }
//            switch CloudKitErrorHandler.shared.resultType(with: error) {
//            case .success:
//                self.databaseChangeToken = newToken
//                // Fetch the changes in zone level
//                self.fetchChangesInZones(callback)
//            case .retry(let timeToWait, _):
//                CloudKitErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait, block: {
//                    self.fetchChangesInDatabase(callback)
//                })
//            case .recoverableError(let reason, _):
//                switch reason {
//                case .changeTokenExpired:
//                    /// The previousServerChangeToken value is too old and the client must re-sync from scratch
//                    self.databaseChangeToken = nil
//                    self.fetchChangesInDatabase(callback)
//                default:
//                    return
//                }
//            default:
//                return
//            }
//        }
//
//        database.add(changesOperation)
//    }
    
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
