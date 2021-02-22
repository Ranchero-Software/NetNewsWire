//
//  RedditFeedProviderTokenRefreshOperation.swift
//  
//
//  Created by Maurice Parker on 8/12/20.
//

import Foundation
import os.log
import RSCore
import OAuthSwift
import Secrets

protocol RedditFeedProviderTokenRefreshOperationDelegate: AnyObject {
	var username: String? { get }
	var oauthTokenLastRefresh: Date? { get set }
	var oauthToken: String { get set }
	var oauthRefreshToken: String { get set }
	var oauthSwift: OAuth2Swift? { get }
}

class RedditFeedProviderTokenRefreshOperation: MainThreadOperation {

	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "RedditFeedProvider")

	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "WebViewProviderReplenishQueueOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var delegate: RedditFeedProviderTokenRefreshOperationDelegate?
	
	var error: Error?
	
	init(delegate: RedditFeedProviderTokenRefreshOperationDelegate) {
		self.delegate = delegate
	}
	
	func run() {
		guard let delegate = delegate, let username = delegate.username else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		// If another operation has recently refreshed the token, we don't need to do it again
		if let lastRefresh = delegate.oauthTokenLastRefresh, Date().timeIntervalSince(lastRefresh) < 120 {
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		os_log(.debug, log: self.log, "Access token expired, attempting to renew...")

		delegate.oauthSwift?.renewAccessToken(withRefreshToken: delegate.oauthRefreshToken) { [weak self] result in
			guard let self = self else { return }
			
			switch result {
			case .success(let tokenSuccess):
				delegate.oauthToken = tokenSuccess.credential.oauthToken
				delegate.oauthRefreshToken = tokenSuccess.credential.oauthRefreshToken
				do {
					try RedditFeedProvider.storeCredentials(username: username, oauthToken: delegate.oauthToken, oauthRefreshToken: delegate.oauthRefreshToken)
					delegate.oauthTokenLastRefresh = Date()
					os_log(.debug, log: self.log, "Access token renewed.")
				} catch {
					self.error = error
					self.operationDelegate?.operationDidComplete(self)
				}
				self.operationDelegate?.operationDidComplete(self)
			case .failure(let oathError):
				self.error = oathError
				self.operationDelegate?.operationDidComplete(self)
			}
		}

	}
	
}
