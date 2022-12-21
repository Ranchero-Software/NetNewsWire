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
	
	case duplicateDefaultTheme

	public var errorDescription: String? {
		switch self {
		case .duplicateAccount:
			return String(localized: "There is already an account of that type with that username created.", comment: "Error message: duplicate account with same username.")
		case .iCloudDriveMissing:
			return String(localized: "Unable to add iCloud Account. Please make sure you have iCloud and iCloud Drive enabled in System Settings.", comment: "Error message: The user cannot enable the iCloud account becasue iCloud or iCloud Drive isn't enabled in Settings.")
		case .userNameAndPasswordRequired:
			return String(localized: "Username and password required", comment: "Error message: The user must provide a username and password.")
		case .invalidUsernameOrPassword:
			return String(localized: "Invalid username or password", comment: "Error message: The user provided an invalid username or password.")
		case .keychainError:
			return String(localized: "Keychain error while storing credentials.", comment: "Error message: Unable to save due a Keychain error.")
		case .duplicateDefaultTheme:
			return String(localized: "You cannot import a theme that shares the same name as a provided theme.", comment: "Error message: cannot import theme as this is a duplicate of a provided theme.")
		}
	}
}
