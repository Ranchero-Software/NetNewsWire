//
//  OAuthAcessTokenRefreshing.swift
//  Account
//
//  Created by Kiel Gillard on 4/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

/// Models section 6 of the OAuth 2.0 Authorization Framework
/// https://tools.ietf.org/html/rfc6749#section-6
public struct OAuthRefreshAccessTokenRequest: Encodable {
	public let grantType = "refresh_token"
	public var refreshToken: String
	public var scope: String?
	
	// Possibly not part of the standard but specific to certain implementations (e.g.: Feedly).
	public var clientId: String
	public var clientSecret: String
	
	public init(refreshToken: String, scope: String?, client: OAuthAuthorizationClient) {
		self.refreshToken = refreshToken
		self.scope = scope
		self.clientId = client.id
		self.clientSecret = client.secret
	}
}

/// Conformed to by API callers to provide a consistent interface for `AccountDelegate` types to refresh OAuth Access Tokens. Conformers provide an associated type that models any custom parameters/properties, as well as the standard ones, in the response to a request for an access token.
/// https://tools.ietf.org/html/rfc6749#section-6
public protocol OAuthAcessTokenRefreshRequesting {
	associatedtype AccessTokenResponse: OAuthAccessTokenResponse
	
	/// Access tokens expire. Perform a request for a fresh access token given the long life refresh token received when authorization was granted.
	/// - Parameter refreshRequest: The refresh token and other information the authorization server requires to grant the client fresh access tokens on the user's behalf.
	/// - Parameter completion: On success, the access token response appropriate for concrete type's service. Both the access and refresh token should be stored, preferrably on the Keychain. On failure, possibly a `URLError` or `OAuthAuthorizationErrorResponse` value.
	func refreshAccessToken(_ refreshRequest: OAuthRefreshAccessTokenRequest, completion: @escaping (Result<AccessTokenResponse, Error>) -> ())
}

/// Implemented by concrete types to perform the actual request.
protocol OAuthAccessTokenRefreshing: AnyObject {
	
	func refreshAccessToken(with refreshToken: String, client: OAuthAuthorizationClient, completion: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ())
}
