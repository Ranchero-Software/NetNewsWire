//
//  AccountUpdateErrors.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 14/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum AccountUpdateErrors: CustomStringConvertible {
	case invalidUsernamePassword, invalidUsernamePasswordAPI, networkError, keyChainError, other(error: Error) , none
	
	var description: String {
		switch self {
		case .invalidUsernamePassword:
			return NSLocalizedString("Invalid email or password combination.", comment: "Invalid email/password combination.")
		case .invalidUsernamePasswordAPI:
			return NSLocalizedString("Invalid email, password, or API URL combination.", comment: "Invalid email/password/API combination.")
		case .networkError:
			return NSLocalizedString("Network Error. Please try later.", comment: "Network Error. Please try later.")
		case .keyChainError:
			return NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
		case .other(let error):
			return NSLocalizedString(error.localizedDescription, comment: "Other add account error")
		default:
			return NSLocalizedString("N/A", comment: "N/A")
		}
	}
	
	static func ==(lhs: AccountUpdateErrors, rhs: AccountUpdateErrors) -> Bool {
		switch (lhs, rhs) {
		case (.other(let lhsError), .other(let rhsError)):
			return lhsError.localizedDescription == rhsError.localizedDescription
		default:
			return false
		}
	}
}
