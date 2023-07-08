//
//  AccountError.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public struct WrappedAccountError: LocalizedError {

    public let accountID: String
    public let underlyingError: Error
    public let isCredentialsError: Bool

    public var errorTitle: String {
        NSLocalizedString("error.title.error", bundle: Bundle.module, comment: "Error")
    }

    public var errorDescription: String? {
        if isCredentialsError {
            let localizedText = NSLocalizedString("error.message.credentials-expired.%@", bundle: Bundle.module, comment: "Your ”%@” credentials have expired.")
            return String(format: localizedText, accountNameForDisplay)
        }

        let localizedText = NSLocalizedString("An error occurred while processing the “%@” account: %@", comment: "Unknown error")
        return String(format: localizedText, accountNameForDisplay, underlyingError.localizedDescription)
    }

    public var recoverySuggestion: String? {
        if isCredentialsError {
            return NSLocalizedString("Please update your credentials for this account, or ensure that your account with this service is still valid.", comment: "Expired credentials")
        }
        return NSLocalizedString("Please try again later.", comment: "Try later")
    }

    private let accountNameForDisplay: String

    @MainActor init(account: Account, underlyingError: Error) {
        self.accountID = account.accountID
        self.underlyingError = underlyingError
        self.accountNameForDisplay = account.nameForDisplay

        var isCredentialsError = false
        if case TransportError.httpError(let status) = underlyingError {
            isCredentialsError = (status == HTTPResponseCode.unauthorized  || status == HTTPResponseCode.forbidden)
        }
        self.isCredentialsError = isCredentialsError
    }
}

public enum AccountError: LocalizedError {
	
	case createErrorNotFound
	case createErrorAlreadySubscribed
	case opmlImportInProgress

    public var errorTitle: String {
        switch self {
        case .createErrorNotFound:
            return NSLocalizedString("error.title.feed-not-found", bundle: Bundle.module, comment: "Unable to Add Feed")
        case .createErrorAlreadySubscribed:
            return NSLocalizedString("error.title.already-subscribed", bundle: Bundle.module, comment: "Already Subscribed")
        case .opmlImportInProgress:
            return NSLocalizedString("error.title.ompl-import-in-progress", bundle: Bundle.module, comment: "OPML Import in Progress")
        }
    }
	
	public var errorDescription: String? {
		switch self {
		case .createErrorNotFound:
            return NSLocalizedString("error.message.feed-not-found", bundle: Bundle.module, comment: "Can’t add a feed because no feed was found.")
		case .createErrorAlreadySubscribed:
            return NSLocalizedString("error.message.feed-already-subscribed", bundle: Bundle.module, comment: "You are already subscribed to this feed and can’t add it again.")
		case .opmlImportInProgress:
            return NSLocalizedString("error.message.opml-import-in-progress", bundle: Bundle.module, comment: "An OPML import for this account is already running.")
		}
	}
	
	public var recoverySuggestion: String? {
		switch self {
		case .createErrorNotFound:
			return nil
		case .createErrorAlreadySubscribed:
			return nil
		default:
			return NSLocalizedString("Please try again later.", comment: "Try later")
		}
	}
}
