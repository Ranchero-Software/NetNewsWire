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
	
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func validateCredentials(completionHandler completion: @escaping (Result<Bool, Error>) -> Void) {
		
		let callURL = feedbinBaseURL.appendingPathComponent("authentication.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		
		transport.send(request: request) { result in
			switch result {
			case .success:
				completion(.success(true))
			case .failure(let error):
				switch error {
				case TransportError.httpError(let status):
					if status == 401 {
						completion(.success(false))
					} else {
						completion(.failure(error))
					}
				default:
					completion(.failure(error))
				}
			}
		}
		
	}
	
	func retrieveSubscriptions(completionHandler completion: @escaping  (Result<[FeedbinFeed], Error>) -> Void) {
		
		let callURL = feedbinBaseURL.appendingPathComponent("subscriptions.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[AccountMetadata.ConditionalGetKeys.subscriptions]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: [FeedbinFeed].self) { [weak self] result in
			switch result {
			case .success(let (headers, feeds)):
				
				self?.storeConditionalGet(metadata: self?.accountMetadata, key: AccountMetadata.ConditionalGetKeys.subscriptions, headers: headers)

			// TODO: Add paging code
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
}

// MARK: Private

extension FeedbinAPICaller {
	
	func storeConditionalGet(metadata: AccountMetadata?, key: String, headers: HTTPHeaders) {
		if var conditionalGet = accountMetadata?.conditionalGetInfo {
			conditionalGet[key] = HTTPConditionalGetInfo(headers: headers)
			accountMetadata?.conditionalGetInfo = conditionalGet
		}
	}
	
}
