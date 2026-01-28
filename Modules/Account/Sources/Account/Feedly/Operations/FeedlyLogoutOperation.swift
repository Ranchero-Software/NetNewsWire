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

final class FeedlyLogoutOperation: FeedlyOperation {

	let service: FeedlyLogoutService
	let account: Account

	init(account: Account, service: FeedlyLogoutService) {
		self.service = service
		self.account = account
	}

	override func run() {
		Feedly.logger.info("Feedly: Requesting logout \(self.account.accountID, privacy: .public)")
		service.logout(completion: didCompleteLogout(_:))
	}

	func didCompleteLogout(_ result: Result<Void, Error>) {
		assert(Thread.isMainThread)
		switch result {
		case .success:
			Feedly.logger.info("Feedly: Logged out of \(self.account.accountID, privacy: .public)")
			do {
				try account.removeCredentials(type: .oauthAccessToken)
				try account.removeCredentials(type: .oauthRefreshToken)
			} catch {
				// oh well, we tried our best.
			}
			didFinish()

		case .failure(let error):
			Feedly.logger.error("Feedly: Logout failed: \(error.localizedDescription)")
			didFinish(with: error)
		}
	}
}
