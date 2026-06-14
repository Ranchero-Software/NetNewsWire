//
//  OAuthAuthorizationCodeGranting.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

/// Client-specific information for requesting an authorization code grant.
/// Accounts are responsible for the scope.
nonisolated public struct OAuthAuthorizationClient: Equatable, Sendable {
	public let id: String
	public let redirectURI: String
	public let state: String?
	public let secret: String

	public init(id: String, redirectURI: String, state: String?, secret: String) {
		self.id = id
		self.redirectURI = redirectURI
		self.state = state
		self.secret = secret
	}
}

/// Models section 4.1.1 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.1
nonisolated public struct OAuthAuthorizationRequest: Sendable {
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
			URLQueryItem(name: "redirect_uri", value: redirectURI)
		]
	}
}

/// Models section 4.1.2 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.2
nonisolated public struct OAuthAuthorizationResponse {
	public let code: String
	public let state: String?
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
nonisolated public struct OAuthAuthorizationErrorResponse: Error, Sendable {
	public let error: OAuthAuthorizationError
	public let state: String?
	public let errorDescription: String?

	public var localizedDescription: String {
		return errorDescription ?? error.rawValue
	}
}

/// Error values as enumerated in section 4.1.2.1 of the OAuth 2.0 Authorization Framework.
/// https://tools.ietf.org/html/rfc6749#section-4.1.2.1
nonisolated public enum OAuthAuthorizationError: String, Sendable {
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
nonisolated public struct OAuthAccessTokenRequest: Encodable, Sendable {
	public let grantType = "authorization_code"
	public let code: String
	public let redirectURI: String
	public let state: String?
	public let clientID: String

	// Possibly not part of the standard but specific to certain implementations (e.g. Feedly).
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

/// Models section 6 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-6
nonisolated public struct OAuthRefreshAccessTokenRequest: Encodable, Sendable {
	public let grantType = "refresh_token"
	public var refreshToken: String
	public var scope: String?

	// Possibly not part of the standard but specific to certain implementations (e.g. Feedly).
	public var clientID: String
	public var clientSecret: String

	public init(refreshToken: String, scope: String?, client: OAuthAuthorizationClient) {
		self.refreshToken = refreshToken
		self.scope = scope
		self.clientID = client.id
		self.clientSecret = client.secret
	}
}

/// Models the minimum subset of properties of a response in section 4.1.4 of the OAuth 2.0 Authorization Framework.
/// Concrete types model other parameters beyond the scope of the OAuth spec.
/// For example, Feedly provides the ID of the user who has consented to the grant.
/// https://tools.ietf.org/html/rfc6749#section-4.1.4
public protocol OAuthAccessTokenResponse {
	var accessToken: String { get }
	var tokenType: String { get }
	var expiresIn: Int { get }
	var refreshToken: String? { get }
	var scope: String { get }
}

/// The access and refresh tokens from a successful authorization grant.
nonisolated public struct OAuthAuthorizationGrant: Equatable, Sendable {
	public let accessToken: Credentials
	public let refreshToken: Credentials?
}

/// Implemented by `AccountDelegate` types that support OAuth authorization code grants.
/// Account dispatches sign-in requests to the concrete delegate via this protocol.
protocol OAuthAuthorizationGranting: AccountDelegate {

	static func oauthAuthorizationCodeGrantRequest() -> URLRequest

	static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse) async throws -> OAuthAuthorizationGrant
}
