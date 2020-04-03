//
//  CloudKitZone.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import os.log
import RSWeb

enum CloudKitZoneError: Error {
	case userDeletedZone
	case invalidParameter
	case unknown
}

protocol CloudKitZoneDelegate: class {
	func cloudKitDidChange(record: CKRecord);
	func cloudKitDidDelete(recordKey: CloudKitRecordKey)
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void);
}

typealias CloudKitRecordKey = (recordType: CKRecord.RecordType, recordID: CKRecord.ID)

protocol CloudKitZone: class {
	
	static var zoneID: CKRecordZone.ID { get }

	var log: OSLog { get }

	var container: CKContainer? { get }
	var database: CKDatabase? { get }
	var delegate: CloudKitZoneDelegate? { get set }

}

extension CloudKitZone {
	
	/// Reset the change token used to determine what point in time we are doing changes fetches
	func resetChangeToken() {
		changeToken = nil
	}
	
	/// Generates a new CKRecord.ID using a UUID for the record's name
	func generateRecordID() -> CKRecord.ID {
		return CKRecord.ID(recordName: UUID().uuidString, zoneID: Self.zoneID)
	}

	/// Subscribe to all changes that happen in this zone
	func subscribe() {
		
		let subscription = CKRecordZoneSubscription(zoneID: Self.zoneID)
        
		let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database?.save(subscription) { _, error in
			switch CloudKitZoneResult.resolve(error) {
			case .success:
				break
			case .retry(let timeToWait):
				self.retryIfPossible(after: timeToWait) {
					self.subscribe()
				}
			default:
				os_log(.error, log: self.log, "%@ zone fetch changes error: %@.", Self.zoneID.zoneName, error?.localizedDescription ?? "Unknown")
			}
		}
	
    }
	
	/// Fetch and process any changes in the zone since the last time we checked when we get a remote notification.
	func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		let note = CKRecordZoneNotification(fromRemoteNotificationDictionary: userInfo)
		guard note?.recordZoneID?.zoneName == Self.zoneID.zoneName else {
			completion()
			return
		}
		
		fetchChangesInZone() { result in
			if case .failure(let error) = result {
				os_log(.error, log: self.log, "%@ zone remote notification fetch error: %@.", Self.zoneID.zoneName, error.localizedDescription)
			}
			completion()
		}
	}
	
	/// Checks to see if the record described in the query exists by retrieving only the testField parameter field.
	func exists(_ query: CKQuery, completion: @escaping (Result<Bool, Error>) -> Void) {
		var recordFound = false
		let op = CKQueryOperation(query: query)
		op.desiredKeys = ["creationDate"]

		op.recordFetchedBlock = { record in
			recordFound = true
		}

		op.queryCompletionBlock =  { [weak self] (_, error) in
			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					completion(.success(recordFound))
				}
			case .retry(let timeToWait):
				self?.retryIfPossible(after: timeToWait) {
					self?.exists(query, completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(error!))
				}
			}
		}

		database?.add(op)
	}
		
	/// Issue a CKQuery and return the resulting CKRecords.s
	func query(_ query: CKQuery, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
		guard let database = database else {
			completion(.failure(CloudKitZoneError.unknown))
			return
		}
		
		database.perform(query, inZoneWith: Self.zoneID) { [weak self] records, error in
			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					if let records = records {
						completion(.success(records))
					} else {
						completion(.failure(CloudKitZoneError.unknown))
					}
				}
			case .retry(let timeToWait):
				self?.retryIfPossible(after: timeToWait) {
					self?.query(query, completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(error!))
				}
			}
		}
	}
	
	/// Fetch a CKRecord by using its externalID
	func fetch(externalID: String?, completion: @escaping (Result<CKRecord, Error>) -> Void) {
		guard let externalID = externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: Self.zoneID)
		
		database?.fetch(withRecordID: recordID) { [weak self] record, error in
			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					if let record = record {
						completion(.success(record))
					} else {
						completion(.failure(CloudKitZoneError.unknown))
					}
				}
			case .retry(let timeToWait):
				self?.retryIfPossible(after: timeToWait) {
					self?.fetch(externalID: externalID, completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(error!))
				}
			}
		}
	}
	
	/// Save the CKRecord
	func save(_ record: CKRecord, completion: @escaping (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [record], recordIDsToDelete: [], completion: completion)
	}
	
	/// Delete a CKRecord using its externalID
	func delete(externalID: String?, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let externalID = externalID else {
			completion(.failure(CloudKitZoneError.invalidParameter))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: Self.zoneID)
		modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
	}
	
	/// Modify and delete the supplied CKRecords and CKRecord.IDs
	func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: @escaping (Result<Void, Error>) -> Void) {
		let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
		
		// We use .changedKeys savePolicy to do unlocked changes here cause my app is contentious and off-line first
		// Apple suggests using .ifServerRecordUnchanged save policy
		// For more, see Advanced CloudKit(https://developer.apple.com/videos/play/wwdc2014/231/)
		op.savePolicy = .changedKeys
		
		// To avoid CKError.partialFailure, make the operation atomic (if one record fails to get modified, they all fail)
		// If you want to handle partial failures, set .isAtomic to false and implement CKOperationResultType .fail(reason: .partialFailure) where appropriate
		op.isAtomic = true
		
		op.modifyRecordsCompletionBlock = { [weak self] (_, _, error) in
			
			guard let self = self else { return }
			
			switch CloudKitZoneResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					completion(.success(()))
				}
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete, completion: completion)
					case .failure(let error):
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			case .userDeletedZone:
				DispatchQueue.main.async {
					completion(.failure(CloudKitZoneError.userDeletedZone))
				}
			case .retry(let timeToWait):
				self.retryIfPossible(after: timeToWait) {
					self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			case .limitExceeded:

				let chunkedRecords = recordsToSave.chunked(into: 300)

				let group = DispatchGroup()
				var errorOccurred = false

				for chunk in chunkedRecords {
					group.enter()
					self.modify(recordsToSave: chunk, recordIDsToDelete: recordIDsToDelete) { result in
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "%@ zone modify records error: %@.", Self.zoneID.zoneName, error.localizedDescription)
							errorOccurred = true
						}
						group.leave()
					}
				}
				
				group.notify(queue: DispatchQueue.main) {
					if errorOccurred {
						completion(.failure(CloudKitZoneError.unknown))
					} else {
						completion(.success(()))
					}
				}
				
			default:
				DispatchQueue.main.async {
					completion(.failure(error!))
				}
			}
		}

		database?.add(op)
	}
	
	/// Fetch all the changes in the CKZone since the last time we checked
    func fetchChangesInZone(completion: @escaping (Result<Void, Error>) -> Void) {

		var changedRecords = [CKRecord]()
		var deletedRecordKeys = [CloudKitRecordKey]()
		
		let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		zoneConfig.previousServerChangeToken = changeToken
		let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [Self.zoneID], configurationsByRecordZoneID: [Self.zoneID: zoneConfig])
        op.fetchAllChanges = true

        op.recordZoneChangeTokensUpdatedBlock = { [weak self] zoneID, token, _ in
            guard let self = self else { return }
			
			DispatchQueue.main.async {
				self.changeToken = token
			}
        }

        op.recordChangedBlock = { [weak self] record in
            guard let self = self else { return }
			
			changedRecords.append(record)
			DispatchQueue.main.async {
				self.delegate?.cloudKitDidChange(record: record)
			}
        }

        op.recordWithIDWasDeletedBlock = { [weak self] recordID, recordType in
            guard let self = self else { return }
			
			let recordKey = CloudKitRecordKey(recordType: recordType, recordID: recordID)
			deletedRecordKeys.append(recordKey)
			
			DispatchQueue.main.async {
				self.delegate?.cloudKitDidDelete(recordKey: recordKey)
			}
        }

        op.recordZoneFetchCompletionBlock = { [weak self] zoneID ,token, _, _, error in
            guard let self = self else { return }

			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					self.changeToken = token
				}
			 case .retry(let timeToWait):
				 self.retryIfPossible(after: timeToWait) {
					 self.fetchChangesInZone(completion: completion)
				 }
			 default:
				os_log(.error, log: self.log, "%@ zone fetch changes error: %@.", zoneID.zoneName, error?.localizedDescription ?? "Unknown")
			}
        }

        op.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            guard let self = self else { return }

			switch CloudKitZoneResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					self.delegate?.cloudKitDidModify(changed: changedRecords, deleted: deletedRecordKeys, completion: completion)
				}
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.fetchChangesInZone(completion: completion)
					case .failure(let error):
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			case .userDeletedZone:
				DispatchQueue.main.async {
					completion(.failure(CloudKitZoneError.userDeletedZone))
				}
			case .retry(let timeToWait):
				self.retryIfPossible(after: timeToWait) {
					self.fetchChangesInZone(completion: completion)
				}
			case .changeTokenExpired:
				DispatchQueue.main.async {
					self.changeToken = nil
					self.fetchChangesInZone(completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(error!))
				}
			}
			
        }

        database?.add(op)
    }
	
}

private extension CloudKitZone {
	
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
	
	func createZoneRecord(completion: @escaping (Result<Void, Error>) -> Void) {
		guard let database = database else {
			completion(.failure(CloudKitZoneError.unknown))
			return
		}

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

	func retryIfPossible(after: Double, block: @escaping () -> ()) {
		let delayTime = DispatchTime.now() + after
		DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
			block()
		})
	}

}
