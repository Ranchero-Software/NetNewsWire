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
	
	public var account: Account? {
		if case .wrappedError(_, let account) = self {
			return account
		} else {
			return nil
		}
	}
	
	public var isCredentialsError: Bool {
		if case .wrappedError(let error, _) = self {
			if case TransportError.httpError(let status) = error {
				return isCredentialsError(status: status)
			}
		}
		return false
	}
    
    public var errorTitle: String {
        switch self {
        case .createErrorNotFound:
            // TODO: Add to Localizable
            return NSLocalizedString("error.title.feed-not-found", bundle: Bundle.module, comment: "Unable to Add Feed")
        case .createErrorAlreadySubscribed:
            // TODO: Add to Localizable
            return NSLocalizedString("error.title.already-subscribed", bundle: Bundle.module, comment: "Already Subscribed")
        case .opmlImportInProgress:
            // TODO: Add to Localizable
            return NSLocalizedString("error.title.ompl-import-in-progress", bundle: Bundle.module, comment: "OPML Import in Progress")
        case .wrappedError(_, _):
            // TODO: Add to Localizable
            return NSLocalizedString("error.title.error", bundle: Bundle.module, comment: "Error")
        }
    }
	
	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
			// TODO: Add to Localizable
            return NSLocalizedString("error.message.feed-not-found", bundle: Bundle.module, comment: "Can’t add a feed because no feed was found.")
		case .createErrorAlreadySubscribed:
            // TODO: Add to Localizable
            return NSLocalizedString("error.message.feed-already-subscribed", bundle: Bundle.module, comment: "You are already subscribed to this feed and can’t add it again.")
		case .opmlImportInProgress:
            // TODO: Add to Localizable
            return NSLocalizedString("error.message.opml-import-in-progress", bundle: Bundle.module, comment: "An OPML import for this account is already running.")
		case .wrappedError(let error, let account):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
                    // TODO: Add to Localizable
                    let localizedText = NSLocalizedString("error.message.credentials-expired.%@", bundle: Bundle.module, comment: "Your ”%@” credentials have expired.")
                    return String(format: localizedText, account.nameForDisplay)
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
	
	func unknownError(_ error: Error, _ account: Account) -> String {
		let localizedText = NSLocalizedString("An error occurred while processing the “%@” account: %@", comment: "Unknown error")
		return NSString.localizedStringWithFormat(localizedText as NSString, account.nameForDisplay, error.localizedDescription) as String
	}
	
	func isCredentialsError(status: Int) -> Bool {
		return status == 401  || status == 403
	}
	
}
