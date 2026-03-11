//
//  Credentials.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/9/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Security

public enum CredentialsError: Error, Sendable {
	case missingUsername
	case missingPassword
	case missingAccessToken
	case missingEndpointURL
	case keychainStoreFailure(status: OSStatus)
	case keychainRetrieveFailure(status: OSStatus)
	case keychainRemoveFailure(status: OSStatus)
}

extension CredentialsError: LocalizedError {

	public var errorDescription: String? {
		switch self {
		case .keychainStoreFailure(let status):
			return "Unable to store credentials in the keychain (\(Self.keychainStatusMessage(status)))."
		case .keychainRetrieveFailure(let status):
			return "Unable to retrieve credentials from the keychain (\(Self.keychainStatusMessage(status)))."
		case .keychainRemoveFailure(let status):
			return "Unable to remove credentials from the keychain (\(Self.keychainStatusMessage(status)))."
		case .missingUsername:
			return "Unable to sync account — missing username."
		case .missingPassword:
			return "Unable to sync account — missing password."
		case .missingAccessToken:
			return "Unable to sync account — missing access token."
		case .missingEndpointURL:
			return "Unable to sync account — missing endpoint URL."
		}
	}

	static func keychainStatusMessage(_ status: OSStatus) -> String {
		if let message = SecCopyErrorMessageString(status, nil) as String? {
			return "error \(status): \(message)"
		}
		return "error \(status)"
	}

	public var recoverySuggestion: String? {
		"Try again in a few minutes. If the problem persists, please report it on the NetNewsWire Discourse forum."
	}
}

public enum CredentialsType: String, Sendable {
	case basic = "password"
	case newsBlurBasic = "newsBlurBasic"
	case newsBlurSessionID = "newsBlurSessionId"
	case readerBasic = "readerBasic"
	case readerAPIKey = "readerAPIKey"
	case oauthAccessToken = "oauthAccessToken"
	case oauthAccessTokenSecret = "oauthAccessTokenSecret"
	case oauthRefreshToken = "oauthRefreshToken"
}

nonisolated public struct Credentials: Equatable, Sendable {
	public let type: CredentialsType
	public let username: String
	public let secret: String

	public init(type: CredentialsType, username: String, secret: String) {
		self.type = type
		self.username = username
		self.secret = secret
	}
}
