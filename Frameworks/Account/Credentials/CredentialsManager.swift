//
//  CredentialsManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public struct CredentialsManager {
	
	public static func storeCredentials(_ credentials: Credentials, server: String) throws {
		
		var query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
										  kSecAttrAccount as String: credentials.username,
										  kSecAttrServer as String: server]
		
		if credentials.type != .basic {
			query[kSecAttrSecurityDomain as String] = credentials.type.rawValue
		}
		
		let secretData = credentials.secret.data(using: String.Encoding.utf8)!
		let attributes: [String: Any] = [kSecValueData as String: secretData]
		let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
		
		switch status {
		case errSecSuccess:
			return
		case errSecItemNotFound:
			break
		default:
			throw CredentialsError.unhandledError(status: status)
		}
		
		guard status == errSecItemNotFound else {
			return
		}
		
		query[kSecValueData as String] = secretData

		let addStatus = SecItemAdd(query as CFDictionary, nil)
		if addStatus != errSecSuccess {
			throw CredentialsError.unhandledError(status: status)
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

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		
		guard status != errSecItemNotFound else {
			return nil
		}
		
		guard status == errSecSuccess else {
			throw CredentialsError.unhandledError(status: status)
		}
		
		guard let existingItem = item as? [String : Any],
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

		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw CredentialsError.unhandledError(status: status)
		}
		
	}
    
}
