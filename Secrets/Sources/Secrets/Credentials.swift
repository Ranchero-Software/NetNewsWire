//
//  Credentials.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/9/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public enum CredentialsError: Error, Sendable {
	case incompleteCredentials
	case unhandledError(status: OSStatus)
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

public struct Credentials: Equatable, Sendable {
	public let type: CredentialsType
	public let username: String
	public let secret: String
	
	public init(type: CredentialsType, username: String, secret: String) {
		self.type = type
		self.username = username
		self.secret = secret
	}
}
