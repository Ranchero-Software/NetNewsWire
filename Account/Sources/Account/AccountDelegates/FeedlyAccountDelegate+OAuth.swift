//
//  FeedlyAccountDelegate+OAuth.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Secrets

/// Models the access token response from Feedly.
/// https://developer.feedly.com/v3/auth/#exchanging-an-auth-code-for-a-refresh-token-and-an-access-token
public struct FeedlyOAuthAccessTokenResponse: Decodable, OAuthAccessTokenResponse, Sendable {
	/// The ID of the Feedly user.
	public var id: String

	// Required properties of the OAuth 2.0 Authorization Framework section 4.1.4.
	public var accessToken: String
	public var tokenType: String
	public var expiresIn: Int
	public var refreshToken: String?
	public var scope: String
}

extension FeedlyAccountDelegate {

	private static let oauthAuthorizationGrantScope = "https://cloud.feedly.com/subscriptions"

	static func oauthAuthorizationCodeGrantRequest(secretsProvider: SecretsProvider) -> URLRequest {
		let client = environment.oauthAuthorizationClient(secretsProvider: secretsProvider)
		let authorizationRequest = OAuthAuthorizationRequest(clientID: client.id,
															 redirectUri: client.redirectUri,
															 scope: oauthAuthorizationGrantScope,
															 state: client.state)
		let baseURLComponents = environment.baseUrlComponents
		return FeedlyAPICaller.authorizationCodeURLRequest(for: authorizationRequest, baseUrlComponents: baseURLComponents)
	}
	
	static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse, transport: any Web.Transport, secretsProvider: any Secrets.SecretsProvider) async throws -> OAuthAuthorizationGrant {

		let client = environment.oauthAuthorizationClient(secretsProvider: secretsProvider)
		let request = OAuthAccessTokenRequest(authorizationResponse: response,
											  scope: oauthAuthorizationGrantScope,
											  client: client)
		let caller = FeedlyAPICaller(transport: transport, api: environment, secretsProvider: secretsProvider)
		let response = try await caller.requestAccessToken(request)

		let accessToken = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
		let refreshToken: Credentials? = {
			guard let token = response.refreshToken else {
				return nil
			}
			return Credentials(type: .oauthRefreshToken, username: response.id, secret: token)
		}()

		let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)
		
		return grant
	}
}

extension FeedlyAccountDelegate {
	
	func refreshAccessToken(with refreshToken: String, client: OAuthAuthorizationClient) async throws -> OAuthAuthorizationGrant {

		let request = OAuthRefreshAccessTokenRequest(refreshToken: refreshToken, scope: nil, client: client)
		let response = try await caller.refreshAccessToken(request)

		let accessToken = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
		let refreshToken: Credentials? = {
			guard let token = response.refreshToken else {
				return nil
			}
			return Credentials(type: .oauthRefreshToken, username: response.id, secret: token)
		}()

		let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)

		return grant
	}
}
