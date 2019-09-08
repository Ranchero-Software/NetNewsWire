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
		
		switch credentials {
		case .basic(let username, let password):
			try storeBasicCredentials(server: server, username: username, password: password)
        case .readerAPIBasicLogin(let username, let password):
            try storeBasicCredentials(server: server, username: username, password: password)
        case .readerAPIAuthLogin(let username, let apiKey):
            try storeBasicCredentials(server: server, username: username, password: apiKey)
        case .oauthAccessToken(let username, let token):
            try storeBasicCredentials(server: server, username: username, password: token)
        case .oauthRefreshToken(let username, let token):
            try storeBasicCredentials(server: server, username: username, password: token)
        }
		
	}
	
	public static func retrieveBasicCredentials(server: String, username: String) throws -> Credentials? {
		
		let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									kSecAttrAccount as String: username,
									kSecAttrServer as String: server,
									kSecMatchLimit as String: kSecMatchLimitOne,
									kSecReturnAttributes as String: true,
									kSecReturnData as String: true]
		
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		
		guard status != errSecItemNotFound else {
			return nil
		}
		
		guard status == errSecSuccess else {
			throw CredentialsError.unhandledError(status: status)
		}
		
		guard let existingItem = item as? [String : Any],
			let passwordData = existingItem[kSecValueData as String] as? Data,
			let password = String(data: passwordData, encoding: String.Encoding.utf8) else {
				return nil
		}
		
		return Credentials.basic(username: username, password: password)
		
	}
	
	public static func removeBasicCredentials(server: String, username: String) throws {
		
		let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									kSecAttrAccount as String: username,
									kSecAttrServer as String: server,
									kSecMatchLimit as String: kSecMatchLimitOne,
									kSecReturnAttributes as String: true,
									kSecReturnData as String: true]
		
		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw CredentialsError.unhandledError(status: status)
		}
		
	}
    
    public static func retrieveReaderAPIAuthCredentials(server: String, username: String) throws -> Credentials? {
        
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: username,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw CredentialsError.unhandledError(status: status)
        }
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8) else {
                return nil
        }
        
        return Credentials.readerAPIAuthLogin(username: username, apiKey: password)
        
    }
    
    public static func removeReaderAPIAuthCredentials(server: String, username: String) throws {
        
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: username,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialsError.unhandledError(status: status)
        }
        
    }
}

// MARK: Private

extension CredentialsManager {
	
	static func storeBasicCredentials(server: String, username: String, password: String) throws {
		
		let passwordData = password.data(using: String.Encoding.utf8)!
		
		let updateQuery: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
										  kSecAttrAccount as String: username,
										  kSecAttrServer as String: server]
		let attributes: [String: Any] = [kSecValueData as String: passwordData]
		let status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
		
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
		
		let addQuery: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
									   kSecAttrAccount as String: username,
									   kSecAttrServer as String: server,
									   kSecValueData as String: passwordData]
		let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
		if addStatus != errSecSuccess {
			throw CredentialsError.unhandledError(status: status)
		}
		
	}
	
}
