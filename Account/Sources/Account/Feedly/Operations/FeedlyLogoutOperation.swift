//
//  FeedlyLogoutOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

protocol FeedlyLogoutService {
	func logout(completion: @escaping (Result<Void, Error>) -> ())
}

final class FeedlyLogoutOperation: FeedlyOperation, Logging {

	let service: FeedlyLogoutService
	let account: Account
	
	init(account: Account, service: FeedlyLogoutService) {
		self.service = service
		self.account = account
	}
	
	override func run() {
        self.logger.debug("Requesting logout of \(String(describing: self.account.type)).")
		service.logout(completion: didCompleteLogout(_:))
	}
	
	func didCompleteLogout(_ result: Result<Void, Error>) {
		assert(Thread.isMainThread)
		switch result {
		case .success:
            self.logger.debug("Logged out of \(String(describing: self.account.type)).")
			do {
				try account.removeCredentials(type: .oauthAccessToken)
				try account.removeCredentials(type: .oauthRefreshToken)
			} catch {
				// oh well, we tried our best.
			}
			didFinish()
			
		case .failure(let error):
            self.logger.error("Logout failed because: \(error.localizedDescription, privacy: .public)")
			didFinish(with: error)
		}
	}
}
