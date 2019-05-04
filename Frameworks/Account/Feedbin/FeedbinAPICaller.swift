//
//  FeedbinAPICaller.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedbinAPICaller: NSObject {
	
	private let feedbinBaseURL = URL(string: "https://api.feedbin.com/v2/")!
	private var transport: Transport!

	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func validateCredentials(username: String, password: String, completionHandler handler: @escaping  (Result<Bool, Error>) -> Void) {
		
		let callURL = feedbinBaseURL.appendingPathComponent("authentication.json")
		let request = URLRequest(url: callURL, username: username, password: password)
		
		transport.send(request: request) { result in
			switch result {
			case .success:
				handler(.success(true))
			case .failure(let error):
				switch error {
				case TransportError.httpError(let status):
					if status == 401 {
						handler(.success(false))
					} else {
						handler(.failure(error))
					}
				default:
					handler(.failure(error))
				}
			}
		}
		
	}
}
