//
//  OAuthAuthorizationCodeGranting.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Secrets

/// Models the access token response from Feedly.
/// <https://developer.feedly.com/v3/auth/#exchanging-an-auth-code-for-a-refresh-token-and-an-access-token>
///
/// Also see: <https://tools.ietf.org/html/rfc6749#section-4.1.4>
public struct FeedlyOAuthAccessTokenResponse: Decodable, Sendable {

	/// The ID of the Feedly user.
	public var id: String

	// Required properties of the OAuth 2.0 Authorization Framework section 4.1.4.
	public var accessToken: String
	public var tokenType: String
	public var expiresIn: Int
	public var refreshToken: String?
	public var scope: String
}

/// Client-specific information for requesting an authorization code grant.
/// Accounts are responsible for the scope.
public struct OAuthAuthorizationClient: Equatable {
	public var id: String
	public var redirectURI: String
	public var state: String?
	public var secret: String

	public init(id: String, redirectURI: String, state: String?, secret: String) {
		self.id = id
		self.redirectURI = redirectURI
		self.state = state
		self.secret = secret
	}
}

/// Models section 4.1.1 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.1
public struct OAuthAuthorizationRequest {
	public let responseType = "code"
	public var clientID: String
	public var redirectURI: String
	public var scope: String
	public var state: String?
	
	public init(clientID: String, redirectURI: String, scope: String, state: String?) {
		self.clientID = clientID
		self.redirectURI = redirectURI
		self.scope = scope
		self.state = state
	}
	
	public var queryItems: [URLQueryItem] {
		return [
			URLQueryItem(name: "response_type", value: responseType),
			URLQueryItem(name: "client_id", value: clientID),
			URLQueryItem(name: "scope", value: scope),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
		]
	}
}

/// Models section 4.1.2 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.2
public struct OAuthAuthorizationResponse {
	public var code: String
	public var state: String?
}

public extension OAuthAuthorizationResponse {
	
	init(url: URL, client: OAuthAuthorizationClient) throws {
		guard let scheme = url.scheme, client.redirectURI.hasPrefix(scheme) else {
			throw URLError(.unsupportedURL)
		}
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			throw URLError(.badURL)
		}
		guard let queryItems = components.queryItems, !queryItems.isEmpty else {
			throw URLError(.unsupportedURL)
		}
		let code = queryItems.first { $0.name.lowercased() == "code" }
		guard let codeValue = code?.value, !codeValue.isEmpty else {
			throw URLError(.unsupportedURL)
		}
		
		let state = queryItems.first { $0.name.lowercased() == "state" }
		let stateValue = state?.value
		
		self.init(code: codeValue, state: stateValue)
	}
}

/// Models section 4.1.2.1 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.2.1
public struct OAuthAuthorizationErrorResponse: Error {
	public var error: OAuthAuthorizationError
	public var state: String?
	public var errorDescription: String?
	
	public var localizedDescription: String {
		return errorDescription ?? error.rawValue
	}
}

/// Error values as enumerated in section 4.1.2.1 of the OAuth 2.0 Authorization Framework.
/// https://tools.ietf.org/html/rfc6749#section-4.1.2.1
public enum OAuthAuthorizationError: String, Sendable {
	case invalidRequest = "invalid_request"
	case unauthorizedClient = "unauthorized_client"
	case accessDenied = "access_denied"
	case unsupportedResponseType = "unsupported_response_type"
	case invalidScope = "invalid_scope"
	case serverError = "server_error"
	case temporarilyUnavailable = "temporarily_unavailable"
}

/// Models section 4.1.3 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.3
public struct OAuthAccessTokenRequest: Encodable, Sendable {
	public let grantType = "authorization_code"
	public var code: String
	public var redirectURI: String
	public var state: String?
	public var clientID: String
	
	// Possibly not part of the standard but specific to certain implementations (e.g.: Feedly).
	public var clientSecret: String
	public var scope: String
	
	public init(authorizationResponse: OAuthAuthorizationResponse, scope: String, client: OAuthAuthorizationClient) {
		self.code = authorizationResponse.code
		self.redirectURI = client.redirectURI
		self.state = authorizationResponse.state
		self.clientID = client.id
		self.clientSecret = client.secret
		self.scope = scope
	}
}

/// The access and refresh tokens from a successful authorization grant.
public struct OAuthAuthorizationGrant: Equatable {
	
	public var accessToken: Credentials
	public var refreshToken: Credentials?

	public init(accessToken: Credentials, refreshToken: Credentials? = nil) {
		self.accessToken = accessToken
		self.refreshToken = refreshToken
	}
}
