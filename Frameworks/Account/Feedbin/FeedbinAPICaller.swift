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
	
	func retrieveTags(completionHandler completion: @escaping (Result<[FeedbinTag]?, Error>) -> Void) {
		
		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let conditionalGet = accountMetadata?.conditionalGetInfo[AccountMetadata.ConditionalGetKeys.tags]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)

		transport.send(request: request, resultType: [FeedbinTag].self) { [weak self] result in
			
			switch result {
			case .success(let (headers, tags)):
				self?.storeConditionalGet(metadata: self?.accountMetadata, key: AccountMetadata.ConditionalGetKeys.tags, headers: headers)
				completion(.success(tags))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func renameTag(oldName: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinRenameTag(oldName: oldName, newName: newName)
		transport.send(request: request, method: HTTPMethod.post, payload: payload, completion: completion)
	}
	
	func deleteTag(name: String, completion: @escaping (Result<[FeedbinTagging]?, Error>) -> Void) {
		
		let callURL = feedbinBaseURL.appendingPathComponent("tags.json")
		let request = URLRequest(url: callURL, credentials: credentials)
		let payload = FeedbinDeleteTag(name: name)
		
		transport.send(request: request, method: HTTPMethod.delete, payload: payload, resultType: [FeedbinTagging].self) { result in

			switch result {
			case .success(let (_, taggings)):
				completion(.success(taggings))
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
