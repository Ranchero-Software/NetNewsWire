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

enum CloudKitZoneError: LocalizedError {
	case userDeletedZone
	case invalidParameter
	case unknown
	
	var errorDescription: String? {
		if case .userDeletedZone = self {
			return NSLocalizedString("The iCloud data was deleted.  Please delete the NetNewsWire iCloud account and add it again to continue using NetNewsWire's iCloud support.", comment: "User deleted zone.")
		} else {
			return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
		}
	}
}

protocol CloudKitZoneDelegate: class {
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey], completion: @escaping (Result<Void, Error>) -> Void);
}

typealias CloudKitRecordKey = (recordType: CKRecord.RecordType, recordID: CKRecord.ID)

protocol CloudKitZone: class {
	
	static var zoneID: CKRecordZone.ID { get }

	var log: OSLog { get }

	var container: CKContainer? { get }
	var database: CKDatabase? { get }
	var delegate: CloudKitZoneDelegate? { get set }

	/// Reset the change token used to determine what point in time we are doing changes fetches
	func resetChangeToken()

	/// Generates a new CKRecord.ID using a UUID for the record's name
	func generateRecordID() -> CKRecord.ID
	
	/// Subscribe to changes at a zone level
	func subscribeToZoneChanges()
	
	/// Process a remove notification
	func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void)
	
}

extension CloudKitZone {
	
	/// Reset the change token used to determine what point in time we are doing changes fetches
	func resetChangeToken() {
		changeToken = nil
	}
	
	func generateRecordID() -> CKRecord.ID {
		return CKRecord.ID(recordName: UUID().uuidString, zoneID: Self.zoneID)
	}

	func retryIfPossible(after: Double, block: @escaping () -> ()) {
		let delayTime = DispatchTime.now() + after
		DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
			block()
		})
	}
	
	func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		let note = CKRecordZoneNotification(fromRemoteNotificationDictionary: userInfo)
		guard note?.recordZoneID?.zoneName == Self.zoneID.zoneName else {
			completion()
			return
		}
		
		fetchChangesInZone() { result in
			if case .failure(let error) = result {
				os_log(.error, log: self.log, "%@ zone remote notification fetch error: %@", Self.zoneID.zoneName, error.localizedDescription)
			}
			completion()
		}
	}

	/// Creates the zone record
	func createZoneRecord(completion: @escaping (Result<Void, Error>) -> Void) {
		guard let database = database else {
			completion(.failure(CloudKitZoneError.unknown))
			return
		}

		database.save(CKRecordZone(zoneID: Self.zoneID)) { (recordZone, error) in
			if let error = error {
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error)))
				}
			} else {
				DispatchQueue.main.async {
					completion(.success(()))
				}
			}
		}
	}

	/// Subscribes to zone changes
	func subscribeToZoneChanges() {
		let subscription = CKRecordZoneSubscription(zoneID: Self.zoneID)
        
		let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
		save(subscription) { result in
			if case .failure(let error) = result {
				os_log(.error, log: self.log, "%@ zone subscribe to changes error: %@", Self.zoneID.zoneName, error.localizedDescription)
			}
		}
    }
		
	/// Issue a CKQuery and return the resulting CKRecords.s
	func query(_ query: CKQuery, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
		guard let database = database else {
			completion(.failure(CloudKitZoneError.unknown))
			return
		}
		
		database.perform(query, inZoneWith: Self.zoneID) { [weak self] records, error in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					if let records = records {
						completion(.success(records))
					} else {
						completion(.failure(CloudKitZoneError.unknown))
					}
				}
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.query(query, completion: completion)
					case .failure(let error):
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			case .retry(let timeToWait):
				os_log(.error, log: self.log, "%@ zone query retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
				self.retryIfPossible(after: timeToWait) {
					self.query(query, completion: completion)
				}
			case .userDeletedZone:
				DispatchQueue.main.async {
					completion(.failure(CloudKitZoneError.userDeletedZone))
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error!)))
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
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch CloudKitZoneResult.resolve(error) {
            case .success:
				DispatchQueue.main.async {
					if let record = record {
						completion(.success(record))
					} else {
						completion(.failure(CloudKitZoneError.unknown))
					}
				}
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.fetch(externalID: externalID, completion: completion)
					case .failure(let error):
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			case .retry(let timeToWait):
				os_log(.error, log: self.log, "%@ zone fetch retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
				self.retryIfPossible(after: timeToWait) {
					self.fetch(externalID: externalID, completion: completion)
				}
			case .userDeletedZone:
				DispatchQueue.main.async {
					completion(.failure(CloudKitZoneError.userDeletedZone))
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error!)))
				}
			}
		}
	}
	
	/// Save the CKRecord
	func save(_ record: CKRecord, completion: @escaping (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [record], recordIDsToDelete: [], completion: completion)
	}
	
	/// Save the CKRecords
	func save(_ records: [CKRecord], completion: @escaping (Result<Void, Error>) -> Void) {
		modify(recordsToSave: records, recordIDsToDelete: [], completion: completion)
	}
	
	/// Saves or modifies the records as long as they are unchanged relative to the local version
	func saveIfNew(_ records: [CKRecord], completion: @escaping (Result<Void, Error>) -> Void) {
		let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [CKRecord.ID]())
		op.savePolicy = .ifServerRecordUnchanged
		op.isAtomic = false
		op.qualityOfService = .userInitiated
		
		op.modifyRecordsCompletionBlock = { [weak self] (_, _, error) in
			
			guard let self = self else { return }
			
			switch CloudKitZoneResult.resolve(error) {
			case .success, .partialFailure:
				DispatchQueue.main.async {
					completion(.success(()))
				}
				
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.saveIfNew(records, completion: completion)
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
					self.saveIfNew(records, completion: completion)
				}
				
			case .limitExceeded:

				let chunkedRecords = records.chunked(into: 300)

				let group = DispatchGroup()
				var errorOccurred = false

				for chunk in chunkedRecords {
					group.enter()
					self.saveIfNew(chunk) { result in
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "%@ zone modify records error: %@", Self.zoneID.zoneName, error.localizedDescription)
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
					completion(.failure(CloudKitError(error!)))
				}
			}
		}

		database?.add(op)
	}

	/// Save the CKSubscription
	func save(_ subscription: CKSubscription, completion: @escaping (Result<CKSubscription, Error>) -> Void) {
		database?.save(subscription) { [weak self] savedSubscription, error in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch CloudKitZoneResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					completion(.success((savedSubscription!)))
				}
			case .zoneNotFound:
				self.createZoneRecord() { result in
					switch result {
					case .success:
						self.save(subscription, completion: completion)
					case .failure(let error):
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}
			case .retry(let timeToWait):
				os_log(.error, log: self.log, "%@ zone save subscription retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
				self.retryIfPossible(after: timeToWait) {
					self.save(subscription, completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error!)))
				}
			}
		}
	}
	
	/// Delete CKRecords using a CKQuery
	func delete(ckQuery: CKQuery, completion: @escaping (Result<Void, Error>) -> Void) {
		
		var records = [CKRecord]()
		
		let op = CKQueryOperation(query: ckQuery)
		op.qualityOfService = .userInitiated
		op.recordFetchedBlock = { record in
			records.append(record)
		}
		
		op.queryCompletionBlock = { [weak self] (cursor, error) in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}


			if let cursor = cursor {
				self.delete(cursor: cursor, carriedRecords: records, completion: completion)
			} else {
				guard !records.isEmpty else {
					DispatchQueue.main.async {
						completion(.success(()))
					}
					return
				}
				
				let recordIDs = records.map { $0.recordID }
				self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
			}
			
		}
		
		database?.add(op)
	}
	
	/// Delete CKRecords using a CKQuery
	func delete(cursor: CKQueryOperation.Cursor, carriedRecords: [CKRecord], completion: @escaping (Result<Void, Error>) -> Void) {
		
		var records = [CKRecord]()
		
		let op = CKQueryOperation(cursor: cursor)
		op.qualityOfService = .userInitiated
		op.recordFetchedBlock = { record in
			records.append(record)
		}
		
		op.queryCompletionBlock = { [weak self] (cursor, error) in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			records.append(contentsOf: carriedRecords)
			
			if let cursor = cursor {
				self.delete(cursor: cursor, carriedRecords: records, completion: completion)
			} else {
				let recordIDs = records.map { $0.recordID }
				self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
			}
			
		}
		
		database?.add(op)
	}
	
	/// Delete a CKRecord using its recordID
	func delete(recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
	}
		
	/// Delete CKRecords
	func delete(recordIDs: [CKRecord.ID], completion: @escaping (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
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
	
	/// Delete a CKSubscription
	func delete(subscriptionID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		database?.delete(withSubscriptionID: subscriptionID) { [weak self] _, error in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch CloudKitZoneResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					completion(.success(()))
				}
			case .retry(let timeToWait):
				os_log(.error, log: self.log, "%@ zone delete subscription retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
				self.retryIfPossible(after: timeToWait) {
					self.delete(subscriptionID: subscriptionID, completion: completion)
				}
			default:
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error!)))
				}
			}
		}
	}

	/// Modify and delete the supplied CKRecords and CKRecord.IDs
	func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: @escaping (Result<Void, Error>) -> Void) {
		guard !(recordsToSave.isEmpty && recordIDsToDelete.isEmpty) else {
			completion(.success(()))
			return
		}

		let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
		op.savePolicy = .changedKeys
		op.isAtomic = true
		op.qualityOfService = .userInitiated

		op.modifyRecordsCompletionBlock = { [weak self] (_, _, error) in
			
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

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
				os_log(.error, log: self.log, "%@ zone modify retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
				self.retryIfPossible(after: timeToWait) {
					self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete, completion: completion)
				}
			case .limitExceeded:
				let recordToSaveChunks = recordsToSave.chunked(into: 300)
				let recordIDsToDeleteChunks = recordIDsToDelete.chunked(into: 300)

				let group = DispatchGroup()
				var errorOccurred = false

				for chunk in recordToSaveChunks {
					group.enter()
					self.modify(recordsToSave: chunk, recordIDsToDelete: []) { result in
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "%@ zone modify records error: %@", Self.zoneID.zoneName, error.localizedDescription)
							errorOccurred = true
						}
						group.leave()
					}
				}
				
				for chunk in recordIDsToDeleteChunks {
					group.enter()
					self.modify(recordsToSave: [], recordIDsToDelete: chunk) { result in
						if case .failure(let error) = result {
							os_log(.error, log: self.log, "%@ zone modify records error: %@", Self.zoneID.zoneName, error.localizedDescription)
							errorOccurred = true
						}
						group.leave()
					}
				}
				
				group.notify(queue: DispatchQueue.global(qos: .background)) {
					if errorOccurred {
						DispatchQueue.main.async {
							completion(.failure(CloudKitZoneError.unknown))
						}
					} else {
						DispatchQueue.main.async {
							completion(.success(()))
						}
					}
				}
				
			default:
				DispatchQueue.main.async {
					completion(.failure(CloudKitError(error!)))
				}
			}
		}

		database?.add(op)
	}

	/// Fetch all the changes in the CKZone since the last time we checked
    func fetchChangesInZone(completion: @escaping (Result<Void, Error>) -> Void) {

		var savedChangeToken = changeToken
		
		var changedRecords = [CKRecord]()
		var deletedRecordKeys = [CloudKitRecordKey]()
		
		let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		zoneConfig.previousServerChangeToken = changeToken
		let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [Self.zoneID], configurationsByRecordZoneID: [Self.zoneID: zoneConfig])
        op.fetchAllChanges = true
		op.qualityOfService = .userInitiated

        op.recordZoneChangeTokensUpdatedBlock = { zoneID, token, _ in
			savedChangeToken = token
        }

        op.recordChangedBlock = { record in
			changedRecords.append(record)
        }

        op.recordWithIDWasDeletedBlock = { recordID, recordType in
			let recordKey = CloudKitRecordKey(recordType: recordType, recordID: recordID)
			deletedRecordKeys.append(recordKey)
        }

        op.recordZoneFetchCompletionBlock = { zoneID ,token, _, _, error in
			if case .success = CloudKitZoneResult.resolve(error) {
				savedChangeToken = token
			}
        }

        op.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
			guard let self = self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch CloudKitZoneResult.resolve(error) {
			case .success:
				DispatchQueue.main.async {
					self.delegate?.cloudKitDidModify(changed: changedRecords, deleted: deletedRecordKeys) { result in
						switch result {
						case .success:
							self.changeToken = savedChangeToken
							completion(.success(()))
						case .failure(let error):
							completion(.failure(error))
						}
					}
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
				os_log(.error, log: self.log, "%@ zone fetch changes retry in %f seconds.", Self.zoneID.zoneName, timeToWait)
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
					completion(.failure(CloudKitError(error!)))
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
	
}
