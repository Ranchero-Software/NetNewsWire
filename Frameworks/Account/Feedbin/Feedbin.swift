//
//  Feedbin.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class Feedbin: WebServiceProvider {

	let account: Account

	struct MethodName {
		static let getSubscriptions = "getSubscriptions"
	}

	init(account: Account) {

		self.account = account
	}

	// MARK: - Feedbin API

	func getSubscriptions() {

		let delegate = FeedbinGetSubscriptionsDelegate(provider: self)
		callAPI(MethodName.getSubscriptions, delegate)
	}
}

private extension Feedbin {

	func callAPI(_ methodName: String, _ delegate: APICallDelegate) {

		let call = APICall(provider: self, methodName: methodName, delegate: delegate)
		run(call)
	}

	func run(_ apiCall: APICall) {

		// TODO: add to url session
	}
}
