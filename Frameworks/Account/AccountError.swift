//
//  AccountError.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public enum AccountError: LocalizedError {
	
	case createErrorNotFound
	case createErrorAlreadySubscribed
	case opmlImportInProgress
	case wrappedError(error: Error, account: Account)
	
	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
			return NSLocalizedString("The feed couldn’t be found and can’t be added.", comment: "Not found")
		case .createErrorAlreadySubscribed:
			return NSLocalizedString("You are already subscribed to this feed and can’t add it again.", comment: "Already subscribed")
		case .opmlImportInProgress:
			return NSLocalizedString("An OPML import for this account is already running.", comment: "Import running")
		case .wrappedError(let error, let account):
			switch error {
			case TransportError.httpError(let status):
				if status == 401 {
					let localizedText = NSLocalizedString("Your “%@” credentials are invalid or expired.", comment: "Invalid or expired")
					return NSString.localizedStringWithFormat(localizedText as NSString, account.nameForDisplay) as String
				} else {
					return unknownError(error, account)
				}
			default:
				return unknownError(error, account)
			}
		}
	}
	
	public var recoverySuggestion: String? {
		switch self {
		case .createErrorNotFound:
			return nil
		case .createErrorAlreadySubscribed:
			return nil
		case .wrappedError(let error, _):
			switch error {
			case TransportError.httpError(let status):
				if status == 401  || status == 403 {
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
	
	private func unknownError(_ error: Error, _ account: Account) -> String {
		let localizedText = NSLocalizedString("An error occurred while processing the “%@” account: %@", comment: "Unknown error")
		return NSString.localizedStringWithFormat(localizedText as NSString, account.nameForDisplay, error.localizedDescription) as String
	}
}
