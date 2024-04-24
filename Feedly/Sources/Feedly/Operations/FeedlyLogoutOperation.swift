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

	@MainActor func logout() async throws
}

public final class FeedlyLogoutOperation: FeedlyOperation {

	let service: FeedlyLogoutService
	let log: OSLog
	
	public init(service: FeedlyLogoutService, log: OSLog) {
		self.service = service
		self.log = log
	}
	
	public override func run() {

		Task { @MainActor in

			do {
				os_log("Requesting logout of Feedly account.")
				try await service.logout()
				os_log("Logged out of Feedly account.")

				// TODO: fix removing credentials
//				try account.removeCredentials(type: .oauthAccessToken)
//				try account.removeCredentials(type: .oauthRefreshToken)

				didFinish()

			} catch {
				os_log("Logout failed because %{public}@.", error as NSError)
				didFinish(with: error)
			}
		}
	}
}
