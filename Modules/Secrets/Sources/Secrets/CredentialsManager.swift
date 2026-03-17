//
//  CredentialsManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import os
import Security
import RSCore
import ErrorLog

public struct CredentialsManager {

	static let CredentialsManagerErrorSourceID = 100

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CredentialsManager")

	private static let keychainGroup: String? = {
		guard let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String else {
			return nil
		}
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let appGroupSuffix = appGroup.suffix(appGroup.count - 6)
		return "\(appIdentifierPrefix)\(appGroupSuffix)"
	}()

	/// Delays used between retry attempts. Total wait across all
	/// retries is 750ms, enough for most transient keychain errors.
	private static let retryDelays: [TimeInterval] = [0.05, 0.1, 0.2, 0.4]

	/// Returns true if the given keychain status is a transient error
	/// worth retrying (as opposed to a permanent failure or a valid
	/// "item not found" result).
	private static func isTransientKeychainError(_ status: OSStatus) -> Bool {
		switch status {
		case errSecSuccess, errSecItemNotFound, errSecDuplicateItem:
			return false
		default:
			return true
		}
	}

	public static func storeCredentials(_ credentials: Credentials, server: String) throws {

		var query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
									kSecAttrAccount as String: credentials.username,
									kSecAttrServer as String: server]

		if credentials.type != .basic {
			query[kSecAttrSecurityDomain as String] = credentials.type.rawValue
		}

		if let securityGroup = keychainGroup {
			query[kSecAttrAccessGroup as String] = securityGroup
		}

		let secretData = credentials.secret.data(using: String.Encoding.utf8)!
		query[kSecValueData as String] = secretData

		var status = SecItemAdd(query as CFDictionary, nil)

		if isTransientKeychainError(status) {
			for delay in retryDelays {
				Thread.sleep(forTimeInterval: delay)
				status = SecItemAdd(query as CFDictionary, nil)
				if !isTransientKeychainError(status) {
					break
				}
			}
		}

		switch status {
		case errSecSuccess:
			return
		case errSecDuplicateItem:
			break
		default:
			logger.error("CredentialsManager: storeCredentials failed — \(CredentialsError.keychainStatusMessage(status), privacy: .public)")
			let error = CredentialsError.keychainStoreFailure(status: status)
			postAppDidEncounterError(operation: "Storing credentials", error: error)
			throw error
		}

		var deleteQuery = query
		deleteQuery.removeValue(forKey: kSecAttrAccessible as String)
		SecItemDelete(deleteQuery as CFDictionary)

		let addStatus = SecItemAdd(query as CFDictionary, nil)
		if addStatus != errSecSuccess {
			logger.error("CredentialsManager: storeCredentials (after delete) failed — \(CredentialsError.keychainStatusMessage(addStatus), privacy: .public)")
			let error = CredentialsError.keychainStoreFailure(status: addStatus)
			postAppDidEncounterError(operation: "Storing credentials after delete", error: error)
			throw error
		}
	}

	public static func retrieveCredentials(type: CredentialsType, server: String, username: String) throws -> Credentials? {

		var query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									kSecAttrAccount as String: username,
									kSecAttrServer as String: server,
									kSecMatchLimit as String: kSecMatchLimitOne,
									kSecReturnAttributes as String: true,
									kSecReturnData as String: true]

		if type != .basic {
			query[kSecAttrSecurityDomain as String] = type.rawValue
		}

		if let securityGroup = keychainGroup {
			query[kSecAttrAccessGroup as String] = securityGroup
		}

		var item: CFTypeRef?
		var status = SecItemCopyMatching(query as CFDictionary, &item)

		if isTransientKeychainError(status) {
			for delay in retryDelays {
				Thread.sleep(forTimeInterval: delay)
				item = nil
				status = SecItemCopyMatching(query as CFDictionary, &item)
				if !isTransientKeychainError(status) {
					break
				}
			}
		}

		guard status != errSecItemNotFound else {
			return nil
		}

		guard status == errSecSuccess else {
			logger.error("CredentialsManager: retrieveCredentials failed — \(CredentialsError.keychainStatusMessage(status), privacy: .public) for type \(type.rawValue, privacy: .public)")
			let error = CredentialsError.keychainRetrieveFailure(status: status)
			postAppDidEncounterError(operation: "Retrieving credentials", error: error)
			throw error
		}

		guard let existingItem = item as? [String: Any],
			let secretData = existingItem[kSecValueData as String] as? Data,
			let secret = String(data: secretData, encoding: String.Encoding.utf8) else {
				return nil
		}

		return Credentials(type: type, username: username, secret: secret)
	}

	public static func removeCredentials(type: CredentialsType, server: String, username: String) throws {

		var query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									kSecAttrAccount as String: username,
									kSecAttrServer as String: server,
									kSecMatchLimit as String: kSecMatchLimitOne,
									kSecReturnAttributes as String: true,
									kSecReturnData as String: true]

		if type != .basic {
			query[kSecAttrSecurityDomain as String] = type.rawValue
		}

		if let securityGroup = keychainGroup {
			query[kSecAttrAccessGroup as String] = securityGroup
		}

		var status = SecItemDelete(query as CFDictionary)

		if isTransientKeychainError(status) {
			for delay in retryDelays {
				Thread.sleep(forTimeInterval: delay)
				status = SecItemDelete(query as CFDictionary)
				if !isTransientKeychainError(status) {
					break
				}
			}
		}

		guard status == errSecSuccess || status == errSecItemNotFound else {
			logger.error("CredentialsManager: removeCredentials failed — \(CredentialsError.keychainStatusMessage(status), privacy: .public)")
			let error = CredentialsError.keychainRemoveFailure(status: status)
			postAppDidEncounterError(operation: "Removing credentials", error: error)
			throw error
		}
	}
}

private extension CredentialsManager {

	static func postAppDidEncounterError(operation: String, error: CredentialsError) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: "CredentialsManager", sourceID: Self.CredentialsManagerErrorSourceID, operation: operation, errorMessage: error.localizedDescription)
		NotificationCenter.default.postOnMainThread(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}
}
