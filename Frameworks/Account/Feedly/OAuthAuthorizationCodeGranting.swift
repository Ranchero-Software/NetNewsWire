//
//  OAuthAuthorizationCodeGranting.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

/// Client-specific information for requesting an authorization code grant.
/// Accounts are responsible for the scope.
public struct OAuthAuthorizationClient {
	public var id: String
	public var redirectUri: String
	public var state: String?
	public var secret: String
	
	public init(id: String, redirectUri: String, state: String?, secret: String) {
		self.id = id
		self.redirectUri = redirectUri
		self.state = state
		self.secret = secret
	}
}

/// Models section 4.1.1 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-4.1.1
public struct OAuthAuthorizationRequest {
	public let responseType = "code"
	public var clientId: String
	public var redirectUri: String
	public var scope: String
	public var state: String?
	
	public init(clientId: String, redirectUri: String, scope: String, state: String?) {
		self.clientId = clientId
		self.redirectUri = redirectUri
		self.scope = scope
		self.state = state
	}
	
	public var queryItems: [URLQueryItem] {
		return [
			URLQueryItem(name: "response_type", value: responseType),
			URLQueryItem(name: "client_id", value: clientId),
			URLQueryItem(name: "scope", value: scope),
			URLQueryItem(name: "redirect_uri", value: redirectUri),
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
		guard let host = url.host, client.redirectUri.contains(host) else {
			throw URLError(.unsupportedURL)
		}
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			throw URLError(.badURL)
		}
		guard let queryItems = components.queryItems, !queryItems.isEmpty else {
			throw URLError(.unsupportedURL)
		}
		let code = queryItems.firstElementPassingTest { $0.name.lowercased() == "code" }
		guard let codeValue = code?.value, !codeValue.isEmpty else {
			throw URLError(.unsupportedURL)
		}
		
		let state = queryItems.firstElementPassingTest { $0.name.lowercased() == "state" }
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
public enum OAuthAuthorizationError: String {
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
public struct OAuthAccessTokenRequest: Encodable {
	public let grantType = "authorization_code"
	public var code: String
	public var redirectUri: String
	public var state: String?
	public var clientId: String
	
	// Possibly not part of the standard but specific to certain implementations (e.g.: Feedly).
	public var clientSecret: String
	public var scope: String
	
	public init(authorizationResponse: OAuthAuthorizationResponse, scope: String, client: OAuthAuthorizationClient) {
		self.code = authorizationResponse.code
		self.redirectUri = client.redirectUri
		self.state = authorizationResponse.state
		self.clientId = client.id
		self.clientSecret = client.secret
		self.scope = scope
	}
}

/// Models the minimum subset of properties of a response in section 4.1.4 of the OAuth 2.0 Authorization Framework
/// Concrete types model other paramters beyond the scope of the OAuth spec.
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
public struct OAuthAuthorizationGrant {
	public var accessToken: Credentials
	public var refreshToken: Credentials?
}

/// Conformed to by API callers to provide a consistent interface for `AccountDelegate` types to enable OAuth Authorization Grants. Conformers provide an associated type that models any custom parameters/properties, as well as the standard ones, in the response to a request for an access token.
/// https://tools.ietf.org/html/rfc6749#section-4.1
public protocol OAuthAuthorizationCodeGrantRequesting {
	associatedtype AccessTokenResponse: OAuthAccessTokenResponse
	
	/// Provides the URL request that allows users to consent to the client having access to their information. Typically loaded by a web view.
	/// - Parameter request: The
	static func authorizationCodeUrlRequest(for request: OAuthAuthorizationRequest) -> URLRequest
		
	
	/// Performs the request for the access token given an authorization code.
	/// - Parameter authorizationRequest: The authorization code and other information the authorization server requires to grant the client access tokes on the user's behalf.
	/// - Parameter completionHandler: On success, the access token response appropriate for concrete type's service. On failure, possibly a `URLError` or `OAuthAuthorizationErrorResponse` value.
	func requestAccessToken(_ authorizationRequest: OAuthAccessTokenRequest, completionHandler: @escaping (Result<AccessTokenResponse, Error>) -> ())
}

protocol OAuthAuthorizationGranting: AccountDelegate {
	
	static func oauthAuthorizationCodeGrantRequest(for client: OAuthAuthorizationClient) -> URLRequest
	
	static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse, client: OAuthAuthorizationClient, transport: Transport, completionHandler: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ())
}
