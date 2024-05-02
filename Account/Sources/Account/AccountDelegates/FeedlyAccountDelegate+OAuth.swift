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
import Feedly

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
