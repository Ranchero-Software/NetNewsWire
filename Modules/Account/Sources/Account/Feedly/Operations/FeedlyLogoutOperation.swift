//
//  FeedlyLogoutOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyLogoutService {
	func logout(completion: @escaping @MainActor (Result<Void, Error>) -> ())
}

final class FeedlyLogoutOperation: FeedlyOperation, @unchecked Sendable {
	let service: FeedlyLogoutService
	let account: Account

	@MainActor init(account: Account, service: FeedlyLogoutService) {
		self.service = service
		self.account = account
		super.init()
	}

	@MainActor override func run() {
		Feedly.logger.info("FeedlyLogoutOperation: Requesting logout \(self.account.accountID, privacy: .public)")
		service.logout(completion: didCompleteLogout(_:))
	}

	@MainActor func didCompleteLogout(_ result: Result<Void, Error>) {
		assert(Thread.isMainThread)
		switch result {
		case .success:
			Feedly.logger.info("FeedlyLogoutOperation: Logged out of \(self.account.accountID, privacy: .public)")
			do {
				try account.removeCredentials(type: .oauthAccessToken)
				try account.removeCredentials(type: .oauthRefreshToken)
			} catch {
				// oh well, we tried our best.
			}
			didComplete()

		case .failure(let error):
			Feedly.logger.error("Feedly: Logout failed: \(error.localizedDescription)")
			didComplete(with: error)
		}
	}
}
