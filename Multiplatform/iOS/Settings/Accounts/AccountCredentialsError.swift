//
//  AccountCredentialsError.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 21/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum AccountCredentialsError: CustomStringConvertible, Equatable {
	case none, keyChain, invalidCredentials, noNetwork, other(error: Error)

	var description: String {
		switch self {
		case .keyChain:
			return NSLocalizedString("Keychain error while storing credentials.", comment: "")
		case .invalidCredentials:
			return NSLocalizedString("Invalid email/password combination.", comment: "")
		case .noNetwork:
			return NSLocalizedString("Network error. Try again later.", comment: "")
		case .other(let error):
			return NSLocalizedString(error.localizedDescription, comment: "Other add account error")
		default:
			return ""
		}
	}

	static func ==(lhs: AccountCredentialsError, rhs: AccountCredentialsError) -> Bool {
		switch (lhs, rhs) {
		case (.other(let lhsError), .other(let rhsError)):
			return lhsError.localizedDescription == rhsError.localizedDescription
		default:
			return false
		}
	}
}
