//
//  CloudKitZone.swift
//  RSCore
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import CloudKit
import os.log
import FoundationExtras

public enum CloudKitZoneError: LocalizedError {
	case userDeletedZone
	case corruptAccount
	case unknown
	
	public var errorDescription: String? {
		switch self {
		case .userDeletedZone:
			return NSLocalizedString("The iCloud data was deleted. Please remove the application iCloud account and add it again to continue using the application’s iCloud support.", comment: "User deleted zone.")
		case .corruptAccount:
			return NSLocalizedString("There is an unrecoverable problem with your application iCloud account. Please make sure you have iCloud and iCloud Drive enabled in System Preferences. Then remove the application iCloud account and add it again.", comment: "Corrupt account.")
		default:
			return NSLocalizedString("An unexpected CloudKit error occurred.", comment: "An unexpected CloudKit error occurred.")
		}
	}
}

public protocol CloudKitZoneDelegate: AnyObject {
	
	func cloudKitDidModify(changed: [CKRecord], deleted: [CloudKitRecordKey]) async throws
}

public typealias CloudKitRecordKey = (recordType: CKRecord.RecordType, recordID: CKRecord.ID)

public protocol CloudKitZone: AnyObject {
	
	static var qualityOfService: QualityOfService { get }

	var zoneID: CKRecordZone.ID { get }

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
	func receiveRemoteNotification(userInfo: [AnyHashable : Any]) async
}

public extension CloudKitZone {
	
	// My observation has been that QoS is treated differently for CloudKit operations on macOS vs iOS.
	// .userInitiated is too aggressive on iOS and can lead the UI slowing down and appearing to block.
	// .default (or lower) on macOS will sometimes hang for extended periods of time and appear to hang.
	static var qualityOfService: QualityOfService {
		#if os(macOS) || targetEnvironment(macCatalyst)
		return .userInitiated
		#else
		return .default
		#endif
	}
	
	var oldChangeTokenKey: String {
		return "cloudkit.server.token.\(zoneID.zoneName)"
	}

	var changeTokenKey: String {
		return "cloudkit.server.token.\(zoneID.zoneName).\(zoneID.ownerName)"
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

	/// Moves the change token to the new key name.  This can eventually be removed.
	func migrateChangeToken() {
		if let tokenData = UserDefaults.standard.object(forKey: oldChangeTokenKey) as? Data,
		   let oldChangeToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData) {
			changeToken = oldChangeToken
			UserDefaults.standard.removeObject(forKey: oldChangeTokenKey)
		}
	}
	
	/// Reset the change token used to determine what point in time we are doing changes fetches
	func resetChangeToken() {
		changeToken = nil
	}
	
	func generateRecordID() -> CKRecord.ID {
		return CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
	}

	func delay(for seconds: Double) async {

		await withCheckedContinuation { continuation in
			self.retryIfPossible(after: seconds) {
				continuation.resume()
			}
		}
	}

	func retryIfPossible(after: Double, block: @escaping @Sendable () -> ()) {
		let delayTime = DispatchTime.now() + after
		DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
			block()
		})
	}
	
	func receiveRemoteNotification(userInfo: [AnyHashable : Any]) async {

		await withCheckedContinuation { continuation in
			Task { @MainActor in
				self.receiveRemoteNotification(userInfo: userInfo) {
					continuation.resume()
				}
			}
		}
	}

	@MainActor func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping @Sendable () -> Void) {
		let note = CKRecordZoneNotification(fromRemoteNotificationDictionary: userInfo)
		guard note?.recordZoneID?.zoneName == zoneID.zoneName else {
			completion()
			return
		}
		
		fetchChangesInZone() { result in
			if case .failure(let error) = result {
				os_log(.error, log: self.log, "%@ zone remote notification fetch error: %@", self.zoneID.zoneName, error.localizedDescription)
			}
			completion()
		}
	}

	/// Retrieves the zone record for this zone only. If the record isn't found it will be created.
	func fetchZoneRecord() async throws -> CKRecordZone? {

		try await withCheckedThrowingContinuation { continuation in
			self.fetchZoneRecord { result in
				switch result {
				case .success(let recordZone):
					continuation.resume(returning: recordZone)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Retrieves the zone record for this zone only. If the record isn't found it will be created.
	func fetchZoneRecord(completion: @escaping @Sendable (Result<CKRecordZone?, Error>) -> Void) {

		let op = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
		op.qualityOfService = Self.qualityOfService

		var zoneRecords = [CKRecordZone.ID : CKRecordZone]()

		op.perRecordZoneResultBlock = { recordZoneID, recordZoneResult in

			switch recordZoneResult {

			case .success(let recordZone):
				zoneRecords[recordZoneID] = recordZone

			case .failure(let error):
				completion(.failure(CloudKitError(error)))
			}
		}

		op.fetchRecordZonesResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success:
				completion(.success(zoneRecords[self.zoneID]))

			case .failure(let error):

				switch CloudKitZoneResult.resolve(error) {
				case .zoneNotFound, .userDeletedZone:
					self.createZoneRecord() { result in
						switch result {
						case .success:
							self.fetchZoneRecord(completion: completion)
						case .failure(let error):
							DispatchQueue.main.async {
								completion(.failure(error))
							}
						}
					}
				case .retry(let timeToWait):
					os_log(.error, log: self.log, "%@ zone fetch changes retry in %f seconds.", self.zoneID.zoneName, timeToWait)
					self.retryIfPossible(after: timeToWait) {
						self.fetchZoneRecord(completion: completion)
					}
				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
		}

		database?.add(op)
	}

	/// Creates the zone record
	func createZoneRecord() async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.createZoneRecord { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Creates the zone record
	func createZoneRecord(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let database = database else {
			completion(.failure(CloudKitZoneError.unknown))
			return
		}

		database.save(CKRecordZone(zoneID: zoneID)) { (recordZone, error) in
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
		let subscription = CKRecordZoneSubscription(zoneID: zoneID)
        
		let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
		save(subscription) { result in
			if case .failure(let error) = result {
				os_log(.error, log: self.log, "%@ zone subscribe to changes error: %@", self.zoneID.zoneName, error.localizedDescription)
			}
		}
    }

	/// Issue a CKQuery and return the resulting CKRecords.
	func query(_ ckQuery: CKQuery, desiredKeys: [String]? = nil) async throws -> [CKRecord] {

		try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				self.query(ckQuery, desiredKeys: desiredKeys) { result in
					switch result {
					case .success(let records):
						continuation.resume(returning: records)
					case .failure(let error):
						continuation.resume(throwing: error)
					}
				}
			}
		}
	}

	/// Issue a CKQuery and return the resulting CKRecords.
	@MainActor func query(_ ckQuery: CKQuery, desiredKeys: [String]? = nil, completion: @escaping @Sendable (Result<[CKRecord], Error>) -> Void) {
		var records = [CKRecord]()
		
		let op = CKQueryOperation(query: ckQuery)
		op.qualityOfService = Self.qualityOfService
		
		if let desiredKeys = desiredKeys {
			op.desiredKeys = desiredKeys
		}
		
		op.recordMatchedBlock = { recordID, recordResult in
			switch recordResult {
			case .success(let record):
				records.append(record)
			case .failure(let error):
				os_log(.error, log: self.log, "query recordMatchedBlock error recordID: %@ error: %@", recordID, error.localizedDescription)
			}
		}
		
		op.queryResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success(let cursor):
				if let cursor {
					Task { @MainActor in
						self.query(cursor: cursor, desiredKeys: desiredKeys, carriedRecords: records, completion: completion)
					}
				} else {
					completion(.success(records))
				}

			case .failure(let error):

				switch CloudKitZoneResult.resolve(error) {

				case .zoneNotFound:
					self.createZoneRecord() { result in
						switch result {
						case .success:
							Task { @MainActor in
								self.query(ckQuery, desiredKeys: desiredKeys, completion: completion)
							}
						case .failure(let error):
							DispatchQueue.main.async {
								completion(.failure(error))
							}
						}
					}

				case .retry(let timeToWait):
					os_log(.error, log: self.log, "%@ zone query retry in %f seconds.", self.zoneID.zoneName, timeToWait)
					self.retryIfPossible(after: timeToWait) {
						Task { @MainActor in
							self.query(ckQuery, desiredKeys: desiredKeys, completion: completion)
						}
					}

				case .userDeletedZone:
					DispatchQueue.main.async {
						completion(.failure(CloudKitZoneError.userDeletedZone))
					}

				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
		}

		database?.add(op)
	}
	
	/// Query CKRecords using a CKQuery Cursor
	func query(cursor: CKQueryOperation.Cursor, desiredKeys: [String]? = nil, carriedRecords: [CKRecord]) async throws -> [CKRecord] {

		try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				self.query(cursor: cursor, desiredKeys: desiredKeys, carriedRecords: carriedRecords) { result in
					switch result {
					case .success(let records):
						continuation.resume(returning: records)
					case .failure(let error):
						continuation.resume(throwing: error)
					}
				}
			}
		}
	}

	/// Query CKRecords using a CKQuery Cursor
	@MainActor func query(cursor: CKQueryOperation.Cursor, desiredKeys: [String]? = nil, carriedRecords: [CKRecord], completion: @escaping @Sendable (Result<[CKRecord], Error>) -> Void) {
		var records = carriedRecords
		
		let op = CKQueryOperation(cursor: cursor)
		op.qualityOfService = Self.qualityOfService
		
		if let desiredKeys = desiredKeys {
			op.desiredKeys = desiredKeys
		}
		
		op.recordMatchedBlock = { recordID, recordResult in
			switch recordResult {
			case .success(let record):
				records.append(record)
			case .failure(let error):
				os_log(.error, log: self.log, "query cursor recordMatchedBlock error recordID: %@ error: %@", recordID, error.localizedDescription)
			}
		}

		op.queryResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success(let newCursor):
				Task { @MainActor in
					if let newCursor = newCursor {
						self.query(cursor: newCursor, desiredKeys: desiredKeys, carriedRecords: records, completion: completion)
					} else {
						completion(.success(records))
					}
				}

			case .failure(let error):

				switch CloudKitZoneResult.resolve(error) {
				case .zoneNotFound:
					self.createZoneRecord() { result in
						switch result {
						case .success:
							Task { @MainActor in
								self.query(cursor: cursor, desiredKeys: desiredKeys, carriedRecords: records, completion: completion)
							}
						case .failure(let error):
							DispatchQueue.main.async {
								completion(.failure(error))
							}
						}
					}
				case .retry(let timeToWait):
					os_log(.error, log: self.log, "%@ zone query retry in %f seconds.", self.zoneID.zoneName, timeToWait)
					self.retryIfPossible(after: timeToWait) {
						Task { @MainActor in
							self.query(cursor: cursor, desiredKeys: desiredKeys, carriedRecords: records, completion: completion)
						}
					}
				case .userDeletedZone:
					DispatchQueue.main.async {
						completion(.failure(CloudKitZoneError.userDeletedZone))
					}
				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
		}

		database?.add(op)
	}
	
	/// Fetch a CKRecord by using its externalID
	func fetch(externalID: String?) async throws -> CKRecord {

		try await withCheckedThrowingContinuation { continuation in
			self.fetch(externalID: externalID) { result in
				switch result {
				case .success(let record):
					continuation.resume(returning: record)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Fetch a CKRecord by using its externalID
	func fetch(externalID: String?, completion: @escaping @Sendable (Result<CKRecord, Error>) -> Void) {
		guard let externalID = externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		
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
				os_log(.error, log: self.log, "%@ zone fetch retry in %f seconds.", self.zoneID.zoneName, timeToWait)
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
	func save (_ record: CKRecord) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.save(record) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Save the CKRecord
	func save(_ record: CKRecord, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [record], recordIDsToDelete: [], completion: completion)
	}
	
	/// Save the CKRecords
	func save(_ records: [CKRecord]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.save(records) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Save the CKRecords
	func save(_ records: [CKRecord], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		modify(recordsToSave: records, recordIDsToDelete: [], completion: completion)
	}
	
	/// Saves or modifies the records as long as they are unchanged relative to the local version
	func saveIfNew(_ records: [CKRecord]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.saveIfNew(records) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Saves or modifies the records as long as they are unchanged relative to the local version
	func saveIfNew(_ records: [CKRecord], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [CKRecord.ID]())
		op.savePolicy = .ifServerRecordUnchanged
		op.isAtomic = false
		op.qualityOfService = Self.qualityOfService
		
		op.modifyRecordsResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success:
				completion(.success(()))

			case .failure(let error):

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

					var chunkedRecords = records.chunked(into: 200)

					func saveChunksIfNew() {
						if let records = chunkedRecords.popLast() {
							self.saveIfNew(records) { result in
								switch result {
								case .success:
									os_log(.info, log: self.log, "Saved %d chunked new records.", records.count)
									saveChunksIfNew()
								case .failure(let error):
									completion(.failure(error))
								}
							}
						} else {
							completion(.success(()))
						}
					}

					saveChunksIfNew()

				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
		}

		database?.add(op)
	}

	/// Save the CKSubscription
	func save(_ subscription: CKSubscription) async throws -> CKSubscription {

		try await withCheckedThrowingContinuation { continuation in
			self.save(subscription) { result in
				switch result {
				case .success(let subscription):
					continuation.resume(returning: subscription)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Save the CKSubscription
	func save(_ subscription: CKSubscription, completion: @escaping @Sendable (Result<CKSubscription, Error>) -> Void) {
		database?.save(subscription) { [weak self] savedSubscription, error in

			guard let self else {
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
				os_log(.error, log: self.log, "%@ zone save subscription retry in %f seconds.", self.zoneID.zoneName, timeToWait)
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
	func delete(ckQuery: CKQuery) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(ckQuery: ckQuery) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete CKRecords using a CKQuery
	func delete(ckQuery: CKQuery, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		var records = [CKRecord]()
		
		let op = CKQueryOperation(query: ckQuery)
		op.qualityOfService = Self.qualityOfService

		op.recordMatchedBlock = { recordID, recordResult in
			switch recordResult {
			case .success(let record):
				records.append(record)
			case .failure(let error):
				os_log(.error, log: self.log, "delete query recordMatchedBlock error recordID: %@ error: %@", recordID, error.localizedDescription)
			}
		}

		op.queryResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success(let cursor):
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

			case .failure(let error):
				completion(.failure(error))
			}
		}
		
		database?.add(op)
	}
	
	/// Delete CKRecords using a CKQuery
	func delete(cursor: CKQueryOperation.Cursor, carriedRecords: [CKRecord]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(cursor: cursor, carriedRecords: carriedRecords) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete CKRecords using a CKQuery
	func delete(cursor: CKQueryOperation.Cursor, carriedRecords: [CKRecord], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		var records = [CKRecord]()
		
		let op = CKQueryOperation(cursor: cursor)
		op.qualityOfService = Self.qualityOfService

		op.recordMatchedBlock = { recordID, recordResult in
			switch recordResult {
			case .success(let record):
				records.append(record)
			case .failure(let error):
				os_log(.error, log: self.log, "delete cursor recordMatchedBlock error recordID: %@ error: %@", recordID, error.localizedDescription)
			}
		}

		op.queryResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success(let cursor):

				records.append(contentsOf: carriedRecords)

				if let cursor {
					self.delete(cursor: cursor, carriedRecords: records, completion: completion)
				} else {
					let recordIDs = records.map { $0.recordID }
					self.modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
		
		database?.add(op)
	}
	
	/// Delete a CKRecord using its recordID
	func delete(recordID: CKRecord.ID) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(recordID: recordID) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete a CKRecord using its recordID
	func delete(recordID: CKRecord.ID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
	}
		
	/// Delete CKRecords
	func delete(recordIDs: [CKRecord.ID]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(recordIDs: recordIDs) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete CKRecords
	func delete(recordIDs: [CKRecord.ID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		modify(recordsToSave: [], recordIDsToDelete: recordIDs, completion: completion)
	}
		
	/// Delete a CKRecord using its externalID
	func delete(externalID: String?) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(externalID: externalID) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete a CKRecord using its externalID
	func delete(externalID: String?, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
		guard let externalID = externalID else {
			completion(.failure(CloudKitZoneError.corruptAccount))
			return
		}

		let recordID = CKRecord.ID(recordName: externalID, zoneID: zoneID)
		modify(recordsToSave: [], recordIDsToDelete: [recordID], completion: completion)
	}
	
	/// Delete a CKSubscription
	func delete(subscriptionID: String) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.delete(subscriptionID: subscriptionID) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Delete a CKSubscription
	func delete(subscriptionID: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
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
				os_log(.error, log: self.log, "%@ zone delete subscription retry in %f seconds.", self.zoneID.zoneName, timeToWait)
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
	func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Modify and delete the supplied CKRecords and CKRecord.IDs
	func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		guard !(recordsToSave.isEmpty && recordIDsToDelete.isEmpty) else {
			DispatchQueue.main.async {
				completion(.success(()))
			}
			return
		}

		let op = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
		op.savePolicy = .changedKeys
		op.isAtomic = true
		op.qualityOfService = Self.qualityOfService

		op.modifyRecordsResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {

			case .success:
				DispatchQueue.main.async {
					completion(.success(()))
				}

			case .failure(let error):

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
					os_log(.error, log: self.log, "%@ zone modify retry in %f seconds.", self.zoneID.zoneName, timeToWait)
					self.retryIfPossible(after: timeToWait) {
						self.modify(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete, completion: completion)
					}
				case .limitExceeded:
					var recordToSaveChunks = recordsToSave.chunked(into: 200)
					var recordIDsToDeleteChunks = recordIDsToDelete.chunked(into: 200)

					func saveChunks(completion: @escaping (Result<Void, Error>) -> Void) {
						if !recordToSaveChunks.isEmpty {
							let records = recordToSaveChunks.removeFirst()
							self.modify(recordsToSave: records, recordIDsToDelete: []) { result in
								switch result {
								case .success:
									os_log(.info, log: self.log, "Saved %d chunked records.", records.count)
									saveChunks(completion: completion)
								case .failure(let error):
									completion(.failure(error))
								}
							}
						} else {
							completion(.success(()))
						}
					}

					func deleteChunks() {
						if !recordIDsToDeleteChunks.isEmpty {
							let records = recordIDsToDeleteChunks.removeFirst()
							self.modify(recordsToSave: [], recordIDsToDelete: records) { result in
								switch result {
								case .success:
									os_log(.info, log: self.log, "Deleted %d chunked records.", records.count)
									deleteChunks()
								case .failure(let error):
									DispatchQueue.main.async {
										completion(.failure(error))
									}
								}
							}
						} else {
							DispatchQueue.main.async {
								completion(.success(()))
							}
						}
					}

					saveChunks() { result in
						switch result {
						case .success:
							deleteChunks()
						case .failure(let error):
							DispatchQueue.main.async {
								completion(.failure(error))
							}
						}
					}

				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
		}

		database?.add(op)
	}

	/// Fetch all the changes in the CKZone since the last time we checked
	@MainActor func fetchChangesInZone() async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.fetchChangesInZone { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	/// Fetch all the changes in the CKZone since the last time we checked
	@MainActor func fetchChangesInZone(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {

		var savedChangeToken = changeToken
		
		var changedRecords = [CKRecord]()
		var deletedRecordKeys = [CloudKitRecordKey]()
		
		let zoneConfig = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		zoneConfig.previousServerChangeToken = changeToken
		let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: zoneConfig])
        op.fetchAllChanges = true
		op.qualityOfService = Self.qualityOfService

        op.recordZoneChangeTokensUpdatedBlock = { zoneID, token, _ in
			savedChangeToken = token
        }

		op.recordWasChangedBlock = { recordID, result in
			
			if let record = try? result.get() {
				changedRecords.append(record)
			}
		}
		
        op.recordWithIDWasDeletedBlock = { recordID, recordType in
			let recordKey = CloudKitRecordKey(recordType: recordType, recordID: recordID)
			deletedRecordKeys.append(recordKey)
        }

		op.recordZoneFetchResultBlock = { recordZoneID, result in

			if let (token, _, _) = try? result.get() {
				savedChangeToken = token
			}
		}

        op.fetchRecordZoneChangesResultBlock = { [weak self] result in

			guard let self else {
				completion(.failure(CloudKitZoneError.unknown))
				return
			}

			switch result {
				
			case .success:
				Task { @MainActor in
					do {
						try await self.delegate?.cloudKitDidModify(changed: changedRecords, deleted: deletedRecordKeys)
						completion(.success(()))
					} catch {
						completion(.failure(error))
					}
				}
				
			case .failure(let error):

				switch CloudKitZoneResult.resolve(error) {
				case .zoneNotFound:
					self.createZoneRecord() { result in
						switch result {
						case .success:
							Task { @MainActor in
								self.fetchChangesInZone(completion: completion)
							}
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
					os_log(.error, log: self.log, "%@ zone fetch changes retry in %f seconds.", self.zoneID.zoneName, timeToWait)
					self.retryIfPossible(after: timeToWait) {
						Task { @MainActor in
							self.fetchChangesInZone(completion: completion)
						}
					}
				case .changeTokenExpired:
					DispatchQueue.main.async {
						self.changeToken = nil
						self.fetchChangesInZone(completion: completion)
					}
				default:
					DispatchQueue.main.async {
						completion(.failure(CloudKitError(error)))
					}
				}
			}
        }

        database?.add(op)
    }
}
