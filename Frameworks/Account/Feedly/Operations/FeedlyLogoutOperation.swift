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
	func logout(completionHandler: @escaping (Result<Void, Error>) -> ())
}

final class FeedlyLogoutOperation: FeedlyOperation {
	let service: FeedlyLogoutService
	let account: Account
	let log: OSLog
	
	init(account: Account, service: FeedlyLogoutService, log: OSLog) {
		self.service = service
		self.account = account
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		os_log("Requesting logout of %{public}@ account.", "\(account.type)")
		service.logout(completionHandler: didCompleteLogout(_:))
	}
	
	func didCompleteLogout(_ result: Result<Void, Error>) {
		assert(Thread.isMainThread)
		switch result {
		case .success:
			os_log("Logged out of %{public}@ account.", "\(account.type)")
			do {
				try account.removeCredentials(type: .oauthAccessToken)
				try account.removeCredentials(type: .oauthRefreshToken)
			} catch {
				// oh well, we tried our best.
			}
			didFinish()
			
		case .failure(let error):
			os_log("Logout failed because %{public}@.", error as NSError)
			didFinish(error)
		}
	}
}
