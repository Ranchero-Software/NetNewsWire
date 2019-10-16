//
//  FeedWranglerAPICaller.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-08-29.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

import Foundation
import RSWeb

final class FeedWranglerAPICaller: NSObject {
	
	private var transport: Transport!
	
	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?
	
	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func validateCredentials(completion: @escaping (Result<Credentials?, Error>) -> Void) {
		let callURL = FeedWranglerConfig.clientURL.appendingPathComponent("users/authorize")
		let request = URLRequest(url: callURL, credentials: credentials)
		let username = self.credentials?.username ?? ""
		
		transport.send(request: request) { result in
			switch result {
			case .success(let (_, data)):
				guard let data = data else {
					completion(.success(nil))
					return
				}
				
				do {
					if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
						if let accessToken = json["access_token"] as? String {
							let authCredentials = Credentials(type: .feedWranglerToken, username: username, secret: accessToken)
							completion(.success(authCredentials))
							return
						}
					}
					
					completion(.success(nil))
				} catch let error {
					completion(.failure(error))
				}
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
	}
	
	func retrieveSubscriptions(completion: @escaping (Result<[FeedWranglerSubscription], Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL.appendingPathComponent("subscriptions/list")
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request, resultType: FeedWranglerSubscriptionsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feeds ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
}
