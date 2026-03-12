//
//  InkwellAccountDelegate+OAuth.swift
//  Account
//
//  Created by Manton Reece on 3/11/26.
//

import Foundation
import RSWeb
import Secrets

extension InkwellAccountDelegate: OAuthAuthorizationGranting {
	private static let oauthAuthorizationGrantScope = "create"

	@MainActor static func oauthAuthorizationCodeGrantRequest() -> URLRequest {
		let client = OAuthAuthorizationClient.inkwellClient
		let authorizationRequest = OAuthAuthorizationRequest(clientId: client.id,
															 redirectUri: client.redirectUri,
															 scope: oauthAuthorizationGrantScope,
															 state: client.state)
		var components = URLComponents()
		components.scheme = "https"
		components.host = "micro.blog"
		components.path = "/indieauth/auth"
		components.queryItems = authorizationRequest.queryItems

		return URLRequest(url: components.url!)
	}

	@MainActor static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse, transport: Transport, completion: @escaping @MainActor (Result<OAuthAuthorizationGrant, Error>) -> Void) {
		let client = OAuthAuthorizationClient.inkwellClient
		let request = InkwellOAuthAccessTokenRequest(authorizationResponse: response, client: client)
		let caller = InkwellAPICaller(transport: transport)

		Task { @MainActor in
			do {
				let tokenResponse = try await caller.requestAccessToken(request)
				let verificationResponse = try await caller.verifyAccessToken(tokenResponse.accessToken)

				guard verificationResponse.hasInkwell else {
					throw InkwellAccountError.inkwellNotEnabled
				}

				let accessToken = Credentials(type: .bearerAccessToken, username: verificationResponse.username, secret: verificationResponse.token)
				let grant = OAuthAuthorizationGrant(accessToken: accessToken, refreshToken: nil)
				completion(.success(grant))
			} catch {
				completion(.failure(error))
			}
		}
	}
}
