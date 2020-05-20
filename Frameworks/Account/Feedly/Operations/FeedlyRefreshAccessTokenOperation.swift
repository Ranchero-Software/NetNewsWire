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

final class FeedlyRefreshAccessTokenOperation: FeedlyOperation {

	let service: OAuthAccessTokenRefreshing
	let oauthClient: OAuthAuthorizationClient
	let account: Account
	let log: OSLog
	
	init(account: Account, service: OAuthAccessTokenRefreshing, oauthClient: OAuthAuthorizationClient, log: OSLog) {
		self.oauthClient = oauthClient
		self.service = service
		self.account = account
		self.log = log
	}
	
	override func run() {
		let refreshToken: Credentials
		
		do {
			guard let credentials = try account.retrieveCredentials(type: .oauthRefreshToken) else {
				os_log(.debug, log: log, "Could not find a refresh token in the keychain. Check the refresh token is added to the Keychain, remove the account and add it again.")
				throw TransportError.httpError(status: 403)
			}
			
			refreshToken = credentials
			
		} catch {
			didFinish(with: error)
			return
		}
		
		os_log(.debug, log: log, "Refreshing access token.")
		
		// Ignore cancellation after the request is resumed otherwise we may continue storing a potentially invalid token!
		service.refreshAccessToken(with: refreshToken.secret, client: oauthClient) { result in
			self.didRefreshAccessToken(result)
		}
	}
	
	private func didRefreshAccessToken(_ result: Result<OAuthAuthorizationGrant, Error>) {
		assert(Thread.isMainThread)
		
		switch result {
		case .success(let grant):
			do {
				os_log(.debug, log: log, "Storing refresh token.")
				// Store the refresh token first because it sends this token to the account delegate.
				if let token = grant.refreshToken {
					try account.storeCredentials(token)
				}
				
				os_log(.debug, log: log, "Storing access token.")
				// Now store the access token because we want the account delegate to use it.
				try account.storeCredentials(grant.accessToken)
				
				didFinish()
			} catch {
				didFinish(with: error)
			}
			
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
