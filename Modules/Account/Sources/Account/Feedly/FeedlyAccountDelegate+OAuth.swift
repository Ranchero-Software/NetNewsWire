//
//  FeedlyAccountDelegate+OAuth.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

/// The access token response from Feedly.
/// https://developer.feedly.com/v3/auth/#exchanging-an-auth-code-for-a-refresh-token-and-an-access-token
nonisolated public struct FeedlyOAuthAccessTokenResponse: Decodable, OAuthAccessTokenResponse, Sendable {

	/// The ID of the Feedly user.
	public let id: String

	// Required properties of the OAuth 2.0 Authorization Framework section 4.1.4.
	public let accessToken: String
	public let tokenType: String
	public let expiresIn: Int
	public let refreshToken: String?
	public let scope: String
}

extension FeedlyAccountDelegate: OAuthAuthorizationGranting {

	private static let oauthAuthorizationGrantScope = "https://cloud.feedly.com/subscriptions"

	@MainActor static func oauthAuthorizationCodeGrantRequest() -> URLRequest {
		let client = environment.oauthAuthorizationClient
		let authorizationRequest = OAuthAuthorizationRequest(clientID: client.id, redirectURI: client.redirectURI, scope: oauthAuthorizationGrantScope, state: client.state)
		return FeedlyAPICaller.authorizationCodeURLRequest(for: authorizationRequest, baseURLComponents: environment.baseURLComponents)
	}

	@MainActor static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse) async throws -> OAuthAuthorizationGrant {
		let client = environment.oauthAuthorizationClient
		let request = OAuthAccessTokenRequest(authorizationResponse: response, scope: oauthAuthorizationGrantScope, client: client)
		let caller = FeedlyAPICaller(api: environment)
		let tokenResponse = try await caller.requestAccessToken(request)

		let accessToken = Credentials(type: .oauthAccessToken, username: tokenResponse.id, secret: tokenResponse.accessToken)
		let refreshToken: Credentials? = tokenResponse.refreshToken.map {
			Credentials(type: .oauthRefreshToken, username: tokenResponse.id, secret: $0)
		}
		return OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)
	}
}
