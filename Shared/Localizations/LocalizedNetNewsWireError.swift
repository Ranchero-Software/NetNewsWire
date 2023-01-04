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
	
	case userNamePasswordAndURLRequired
	
	case userNameRequired
	
	case invalidUsernameOrPassword
	
	case invalidURL
	
	case keychainError
	
	case duplicateDefaultTheme
	
	case networkError
	
	case unrecognizedAccount

	public var errorDescription: String? {
		switch self {
		case .duplicateAccount:
			return NSLocalizedString("alert.error.duplicate-account-username", comment: "There is already an account of that type with that username created.")
		case .iCloudDriveMissing:
			return NSLocalizedString("alert.error.cloudkit-missing", comment: "Unable to add iCloud Account. Please make sure you have iCloud and iCloud Drive enabled in System Settings.")
		case .userNameAndPasswordRequired:
			return NSLocalizedString("alert.error.username-and-password-required", comment: "Error message: The user must provide a username and password.")
		case .userNamePasswordAndURLRequired:
			return NSLocalizedString("alert.error.username-password-url-required", comment: "The user must provide a username, password, and URL.")
		case .userNameRequired:
			return NSLocalizedString("alert.error.username-required", comment: "Username required.")
		case .invalidUsernameOrPassword:
			return NSLocalizedString("alert.error.invalid-username-or-password", comment: "Error message: The user provided an invalid username or password.")
		case .invalidURL:
			return NSLocalizedString("alert.error.invalid-api-url", comment: "Invalid API URL.")
		case .keychainError:
			return NSLocalizedString("alert.error.keychain-error", comment: "Error message: Unable to save due a Keychain error.")
		case .duplicateDefaultTheme:
			return NSLocalizedString("alert.error.theme-duplicate-of-provided", comment: "Error message: This theme shares the same name as a provided theme and cannot be imported.")
		case .networkError:
			return NSLocalizedString("alert.error.network-error", comment: "Network error. Please try later.")
		case .unrecognizedAccount:
			return NSLocalizedString("alert.error.unrecognized-account", comment: "The account type in invalid.")
		}
	}
}
