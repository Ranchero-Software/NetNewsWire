//
//  LocalizedNetNewsWireError.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 16/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

public enum LocalizedNetNewsWireError: LocalizedError {
	
	/// Displayed when the user tries to create a duplicate
	/// account with the same username.
	case duplicateAccount
	
	/// Displayed when the user attempts to add a
	/// iCloud account but iCloud and/or iCloud Drive
	/// are not enabled.
	case iCloudDriveMissing
	
	case userNameAndPasswordRequired
	
	case invalidUsernameOrPassword
	
	case keychainError

	public var errorDescription: String? {
		switch self {
		case .duplicateAccount:
			return Bundle.main.localizedString(forKey: "DUPLICATE_ACCOUNT_ERROR", value: nil, table: "Errors")
		case .iCloudDriveMissing:
			return Bundle.main.localizedString(forKey: "CLOUDKIT_NOT_ENABLED_ERROR", value: nil, table: "Errors")
		case .userNameAndPasswordRequired:
			return Bundle.main.localizedString(forKey: "USERNAME_AND_PASSWORD_REQUIRED", value: nil, table: "Errors")
		case .invalidUsernameOrPassword:
			return Bundle.main.localizedString(forKey: "INVALID_USERNAME_PASSWORD", value: nil, table: "Errors")
		case .keychainError:
			return Bundle.main.localizedString(forKey: "KEYCHAIN_ERROR", value: nil, table: "Errors")
		}
	}
}
