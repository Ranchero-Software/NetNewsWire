//
//  FeedlyAccountDelegate+OAuth.swift
//  Account
//
//  Created by Kiel Gillard on 14/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

/// Models the access token response from Feedly.
/// https://developer.feedly.com/v3/auth/#exchanging-an-auth-code-for-a-refresh-token-and-an-access-token
public struct FeedlyOAuthAccessTokenResponse: Decodable, OAuthAccessTokenResponse {
	/// The ID of the Feedly user.
	public var id: String

	// Required properties of the OAuth 2.0 Authorization Framework section 4.1.4.
	public var accessToken: String
	public var tokenType: String
	public var expiresIn: Int
	public var refreshToken: String?
	public var scope: String
}

extension FeedlyAccountDelegate: OAuthAuthorizationGranting {
	
	private static let oauthAuthorizationGrantScope = "https://cloud.feedly.com/subscriptions"
	
	static func oauthAuthorizationCodeGrantRequest(for client: OAuthAuthorizationClient) -> URLRequest {
		let authorizationRequest = OAuthAuthorizationRequest(clientId: client.id,
															 redirectUri: client.redirectUri,
															 scope: oauthAuthorizationGrantScope,
															 state: client.state)
		return FeedlyAPICaller.authorizationCodeUrlRequest(for: authorizationRequest)
	}
	
	static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse, client: OAuthAuthorizationClient, transport: Transport, completionHandler: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ()) {
		let request = OAuthAccessTokenRequest(authorizationResponse: response,
											  scope: oauthAuthorizationGrantScope,
											  client: client)
		let caller = FeedlyAPICaller(transport: transport, api: .default)
		caller.requestAccessToken(request) { result in
			switch result {
			case .success(let response):
				let accessToken = Credentials(type: .oauthAccessToken, username: response.id, secret: response.accessToken)
				
				let refreshToken: Credentials? = {
					guard let token = response.refreshToken else {
						return nil
					}
					return Credentials(type: .oauthRefreshToken, username: response.id, secret: token)
				}()
				
				let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: refreshToken)
				
				completionHandler(.success(grant))
				
			case .failure(let error):
				completionHandler(.failure(error))
			}
		}
	}
}
