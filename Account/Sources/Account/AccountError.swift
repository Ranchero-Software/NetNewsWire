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
            return String(localized: "error.title.feed-not-found", bundle: .module, comment: "Unable to Add Feed")
        case .createErrorAlreadySubscribed:
            return String(localized: "error.title.already-subscribed", bundle: .module, comment: "Already Subscribed")
        case .opmlImportInProgress:
            return String(localized: "error.title.ompl-import-in-progress", bundle: .module, comment: "OPML Import in Progress")
        case .wrappedError(_, _):
            return String(localized: "error.title.error", bundle: .module, comment: "Error")
        }
    }
	
	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
            return String(localized: "error.message.feed-not-found", bundle: .module, comment: "Can’t add a feed because no feed was found.")
		case .createErrorAlreadySubscribed:
            return String(localized: "error.message.feed-already-subscribed", bundle: .module, comment: "You are already subscribed to this feed and can’t add it again.")
		case .opmlImportInProgress:
            return String(localized: "error.message.opml-import-in-progress", bundle: Bundle.module, comment: "An OPML import for this account is already running.")
		case .wrappedError(let error, let account):
			switch error {
			case TransportError.httpError(let status):
				if isCredentialsError(status: status) {
                    let localizedText = String(localized: "error.message.credentials-expired.%@", bundle: .module, comment: "Your ”%@” credentials have expired.")
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
                    return String(localized: "Please update your credentials for this account, or ensure that your account with this service is still valid.", bundle: .module, comment: "Expired credentials")
				} else {
                    return String(localized: "Please try again later.", bundle: .module, comment: "Try later")
				}
			default:
                return String(localized: "Please try again later.", bundle: .module, comment: "Try later")
			}
		default:
            return String(localized: "Please try again later.", bundle: .module, comment: "Try later")
		}
	}
	
}

// MARK: Private

private extension AccountError {
	
	func unknownError(_ error: Error, _ account: Account) -> String {
        let localizedText = String(localized: "An error occurred while processing the “%@” account: %@", bundle: .module, comment: "Unknown error")
		return NSString.localizedStringWithFormat(localizedText as NSString, account.nameForDisplay, error.localizedDescription) as String
	}
	
	func isCredentialsError(status: Int) -> Bool {
		return status == 401  || status == 403
	}
	
}
