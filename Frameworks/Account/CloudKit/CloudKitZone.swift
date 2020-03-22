//
//  CloudKitZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit

public protocol CloudKitZone: class {
	
	var container: CKContainer { get }
	var database: CKDatabase { get }
	static var zoneID: CKRecordZone.ID { get }
	
	func startUp(completion: @escaping (Result<Void, Error>) -> Void)
	
	//    func prepare()
	
	//    func fetchChangesInDatabase(_ callback: ((Error?) -> Void)?)
	
	/// The CloudKit Best Practice is out of date, now use this:
	/// https://developer.apple.com/documentation/cloudkit/ckoperation
	/// Which problem does this func solve? E.g.:
	/// 1.(Offline) You make a local change, involve a operation
	/// 2. App exits or ejected by user
	/// 3. Back to app again
	/// The operation resumes! All works like a magic!
	func resumeLongLivedOperationIfPossible()
	
}

extension CloudKitZone {
	
	func startUp(completion: @escaping (Result<Void, Error>) -> Void) {
		database.save(CKRecordZone(zoneID: Self.zoneID)) { (recordZone, error) in
			if let error = error {
				completion(.failure(error))
			} else {
				completion(.success(()))
			}
		}
	}
	
	//    func prepare() {
	//        syncObjects.forEach {
	//            $0.pipeToEngine = { [weak self] recordsToStore, recordIDsToDelete in
	//                guard let self = self else { return }
	//                self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete)
	//            }
	//        }
	//    }
	
	func resumeLongLivedOperationIfPossible() {
		container.fetchAllLongLivedOperationIDs { [weak self]( opeIDs, error) in
			guard let self = self, error == nil, let ids = opeIDs else { return }
			for id in ids {
				self.container.fetchLongLivedOperation(withID: id, completionHandler: { [weak self](ope, error) in
					guard let self = self, error == nil else { return }
					if let modifyOp = ope as? CKModifyRecordsOperation {
						modifyOp.modifyRecordsCompletionBlock = { (_,_,_) in
							print("Resume modify records success!")
						}
						self.container.add(modifyOp)
					}
				})
			}
		}
	}
	
	//    func startObservingRemoteChanges() {
	//        NotificationCenter.default.addObserver(forName: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, queue: nil, using: { [weak self](_) in
	//            guard let self = self else { return }
	//            DispatchQueue.global(qos: .utility).async {
	//                self.fetchChangesInDatabase(nil)
	//            }
	//        })
	//    }
	
	/// Sync local data to CloudKit
	/// For more about the savePolicy: https://developer.apple.com/documentation/cloudkit/ckrecordsavepolicy
	public func syncRecordsToCloudKit(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: ((Error?) -> ())? = nil) {
		let modifyOpe = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
		
		let config = CKOperation.Configuration()
		config.isLongLived = true
		modifyOpe.configuration = config
		
		// We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
		// Apple suggests using .ifServerRecordUnchanged save policy
		// For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
		modifyOpe.savePolicy = .changedKeys
		
		// To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
		// If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
		modifyOpe.isAtomic = true
		
		modifyOpe.modifyRecordsCompletionBlock = {
			[weak self]
			(_, _, error) in
			
			guard let self = self else { return }
			
			switch CloudKitErrorHandler.shared.resultType(with: error) {
			case .success:
				DispatchQueue.main.async {
					completion?(nil)
				}
			case .retry(let timeToWait, _):
				CloudKitErrorHandler.shared.retryOperationIfPossible(retryAfter: timeToWait) {
					self.syncRecordsToCloudKit(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			case .chunk:
				/// CloudKit says maximum number of items in a single request is 400.
				/// So I think 300 should be fine by them.
				let chunkedRecords = recordsToStore.chunked(into: 300)
				for chunk in chunkedRecords {
					self.syncRecordsToCloudKit(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			default:
				return
			}
		}
		
		database.add(modifyOpe)
	}
	
}

