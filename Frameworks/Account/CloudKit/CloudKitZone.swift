//
//  CloudKitZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit

public enum CloudKitZoneError: Error {
	case unknown
}

public protocol CloudKitZone: class {
	
	static var zoneID: CKRecordZone.ID { get }

	var container: CKContainer { get }
	var database: CKDatabase { get }
	
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
	
	var changeTokenKey: String {
		return "cloudkit.server.token.\(Self.zoneID.zoneName)"
	}

    var changeToken: CKServerChangeToken? {
        get {
			guard let tokenData = UserDefaults.standard.object(forKey: changeTokenKey) as? Data else { return nil }
			return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        set {
            guard let token = newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) else {
                UserDefaults.standard.removeObject(forKey: changeTokenKey)
                return
            }
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        }
    }

	var zoneConfiguration: CKFetchRecordZoneChangesOperation.ZoneConfiguration {
		let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		config.previousServerChangeToken = changeToken
		return config
    }
	
	func generateRecordID() -> CKRecord.ID {
		return CKRecord.ID(recordName: UUID().uuidString, zoneID: Self.zoneID)
	}

	func createZoneRecord(completion: @escaping (Result<Void, Error>) -> Void) {
		database.save(CKRecordZone(zoneID: Self.zoneID)) { (recordZone, error) in
			if let error = error {
				DispatchQueue.main.async {
					completion(.failure(error))
				}
			} else {
				DispatchQueue.main.async {
					completion(.success(()))
				}
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
	public func modify(recordsToStore: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: @escaping (Result<Void, Error>) -> Void) {
		let op = CKModifyRecordsOperation(recordsToSave: recordsToStore, recordIDsToDelete: recordIDsToDelete)
		
		let config = CKOperation.Configuration()
		config.isLongLived = true
		op.configuration = config
		
		// We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
		// Apple suggests using .ifServerRecordUnchanged save policy
		// For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
		op.savePolicy = .changedKeys
		
		// To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
		// If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
		op.isAtomic = true
		
		op.modifyRecordsCompletionBlock = { [weak self] (_, _, error) in
			
			guard let self = self else { return }
			
			switch CloudKitResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					completion(.success(()))
				}
			case .noZone:
				self.createZoneRecord() { result in
					// TODO: Need to rebuild (push) zone data here...
					switch result {
					case .success:
						self.modify(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
					case .failure(let error):
						completion(.failure(error))
					}
				}
			case .retry(let timeToWait):
				self.retryOperationIfPossible(retryAfter: timeToWait) {
					self.modify(recordsToStore: recordsToStore, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			case .chunk:
				/// CloudKit says maximum number of items in a single request is 400.
				/// So I think 300 should be fine by them.
				let chunkedRecords = recordsToStore.chunked(into: 300)
				for chunk in chunkedRecords {
					self.modify(recordsToStore: chunk, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			default:
				return
			}
		}
		
		database.add(op)
	}
	
	func retryOperationIfPossible(retryAfter: Double, block: @escaping () -> ()) {
		let delayTime = DispatchTime.now() + retryAfter
		DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
			block()
		})
	}
	
}

