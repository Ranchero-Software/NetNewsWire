//
//  FeedlyLogoutOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

public protocol FeedlyLogoutService {
	func logout(completion: @escaping (Result<Void, Error>) -> ())
}

public final class FeedlyLogoutOperation: FeedlyOperation {

	let service: FeedlyLogoutService
	let log: OSLog
	
	public init(service: FeedlyLogoutService, log: OSLog) {
		self.service = service
		self.log = log
	}
	
	public override func run() {
		os_log("Requesting logout of Feedly account.")
		service.logout(completion: didCompleteLogout(_:))
	}
	
	func didCompleteLogout(_ result: Result<Void, Error>) {
		assert(Thread.isMainThread)
		switch result {
		case .success:
			os_log("Logged out of Feedly account.")
			do {
				// TODO: fix removing credentials
//				try account.removeCredentials(type: .oauthAccessToken)
//				try account.removeCredentials(type: .oauthRefreshToken)
			} catch {
				// oh well, we tried our best.
			}
			didFinish()
			
		case .failure(let error):
			os_log("Logout failed because %{public}@.", error as NSError)
			didFinish(with: error)
		}
	}
}
