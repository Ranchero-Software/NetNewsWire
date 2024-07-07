//
//  CommonError.swift
//
//
//  Created by Brent Simmons on 4/6/24.
//

import Foundation
import Web

public enum AccountError: LocalizedError {

	case createErrorNotFound
	case createErrorAlreadySubscribed
	case opmlImportInProgress
	case wrappedError(error: Error, accountID: String, accountName: String)

	@MainActor public var isCredentialsError: Bool {
		if case .wrappedError(let error, _, _) = self {
			if case TransportError.httpError(let status) = error {
				return isCredentialsError(status: status)
			}
		}
		return false
	}

	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
			return NSLocalizedString("The feed couldn’t be found and can’t be added.", comment: "Not found")
		case .createErrorAlreadySubscribed:
			return NSLocalizedString("You are already subscribed to this feed and can’t add it again.", comment: "Already subscribed")
		case .opmlImportInProgress:
			return NSLocalizedString("An OPML import for this account is already running.", comment: "Import running")
		case .wrappedError(let error, _, let accountName):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
					let localizedText = NSLocalizedString("Your “%@” credentials are invalid or expired.", comment: "Invalid or expired")
					return NSString.localizedStringWithFormat(localizedText as NSString, accountName) as String
				} else {
					return unknownError(error, accountName)
				}
			default:
				return unknownError(error, accountName)
			}
		}
	}

	public var recoverySuggestion: String? {
		switch self {
		case .createErrorNotFound:
			return nil
		case .createErrorAlreadySubscribed:
			return nil
		case .wrappedError(let error, _, _):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
					return NSLocalizedString("Please update your credentials for this account, or ensure that your account with this service is still valid.", comment: "Expired credentials")
				} else {
					return NSLocalizedString("Please try again later.", comment: "Try later")
				}
			default:
				return NSLocalizedString("Please try again later.", comment: "Try later")
			}
		default:
			return NSLocalizedString("Please try again later.", comment: "Try later")
		}
	}

}

// MARK: Private

private extension AccountError {

	func unknownError(_ error: Error, _ accountName: String) -> String {
		let localizedText = NSLocalizedString("An error occurred while processing the “%@” account: %@", comment: "Unknown error")
		return NSString.localizedStringWithFormat(localizedText as NSString, accountName, error.localizedDescription) as String
	}

	func isCredentialsError(status: Int) -> Bool {
		return status == 401  || status == 403
	}
}
