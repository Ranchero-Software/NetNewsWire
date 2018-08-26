//
//  FeedbinGetSubscriptionsDelegate.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import RSParser

struct FeedbinGetSubscriptionsDelegate: APICallDelegate {

	let provider: Feedbin

	func apiCallURLRequest(_ call: APICall) -> URLRequest? {

		return nil // TODO
	}

	func apiCall(_ call: APICall, parseReturnedObjectWith result: HTTPResult) -> Any? {

		guard let data = result.data, let jsonArray = JSONUtilities.array(with: data) else {
			return nil
		}

		return FeedbinSubscription.subscriptions(with: jsonArray)
	}

	func apiCall(_ call: APICall, handleErrorWith: HTTPResult, returnedObject: Any?) {

		// TODO
	}

	func apiCall(_ call: APICall, performActionWith: HTTPResult, returnedObject: Any?) {

		// TODO
	}


}
