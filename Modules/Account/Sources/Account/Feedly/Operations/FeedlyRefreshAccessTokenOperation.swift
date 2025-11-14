//
//  FeedlyRefreshAccessTokenOperation.swift
//  Account
//
//  Created by Kiel Gillard on 4/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import Secrets

final class FeedlyRefreshAccessTokenOperation: FeedlyOperation, @unchecked Sendable {

	let service: OAuthAccessTokenRefreshing
	let oauthClient: OAuthAuthorizationClient
	let account: Account

	@MainActor init(account: Account, service: OAuthAccessTokenRefreshing, oauthClient: OAuthAuthorizationClient) {
		self.oauthClient = oauthClient
		self.service = service
		self.account = account
		super.init()
	}

	@MainActor override func run() {
		let refreshToken: Credentials

		do {
			guard let credentials = try account.retrieveCredentials(type: .oauthRefreshToken) else {
				Feedly.logger.error("Feedly: Could not find a refresh token in the keychain. Check the refresh token is added to the Keychain, remove the account and add it again")
				throw TransportError.httpError(status: 403)
			}

			refreshToken = credentials

		} catch {
			didComplete(with: error)
			return
		}

		Feedly.logger.info("Feedly: Refreshing access token")

		// Ignore cancellation after the request is resumed otherwise we may continue storing a potentially invalid token!
		service.refreshAccessToken(with: refreshToken.secret, client: oauthClient) { result in
			Task { @MainActor in
				self.didRefreshAccessToken(result)
			}
		}
	}

	@MainActor private func didRefreshAccessToken(_ result: Result<OAuthAuthorizationGrant, Error>) {
		assert(Thread.isMainThread)

		switch result {
		case .success(let grant):
			do {
				Feedly.logger.info("Feedly: Storing refresh token")
				// Store the refresh token first because it sends this token to the account delegate.
				if let token = grant.refreshToken {
					try account.storeCredentials(token)
				}

				Feedly.logger.info("Feedly: Storing access token")
				// Now store the access token because we want the account delegate to use it.
				try account.storeCredentials(grant.accessToken)

				didComplete()
			} catch {
				didComplete(with: error)
			}

		case .failure(let error):
			didComplete(with: error)
		}
	}
}
