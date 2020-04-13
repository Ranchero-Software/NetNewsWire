//
//  FeedWranglerAPICaller.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-08-29.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

import Foundation
import SyncDatabase
import RSWeb

enum FeedWranglerError : Error {
	case general(message: String)
}

final class FeedWranglerAPICaller: NSObject {
	
	private var transport: Transport!
	
	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?
	
	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func cancelAll() {
		transport.cancelAll()
	}
	
	func logout(completion: @escaping (Result<Void, Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL.appendingPathComponent("users/logout")
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request) { result in
			switch result {
			case .success:
				completion(.success(()))
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func validateCredentials(completion: @escaping (Result<Credentials?, Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL.appendingPathComponent("users/authorize")
		let username = self.credentials?.username ?? ""

		standardSend(url: url, resultType: FeedWranglerAuthorizationResult.self) { result in
			switch result {
			case .success(let (_, results)):
				if let accessToken = results?.accessToken {
					let authCredentials = Credentials(type: .feedWranglerToken, username: username, secret: accessToken)
					completion(.success(authCredentials))
				} else {
					completion(.success(nil))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveSubscriptions(completion: @escaping (Result<[FeedWranglerSubscription], Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL.appendingPathComponent("subscriptions/list")
		
		standardSend(url: url, resultType: FeedWranglerSubscriptionsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feeds ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func addSubscription(url: String, completion: @escaping (Result<FeedWranglerSubscription, Error>) -> Void) {
		let url = FeedWranglerConfig
			.clientURL
			.appendingPathComponent("subscriptions/add_feed_and_wait")
			.appendingQueryItems([
				URLQueryItem(name: "feed_url", value: url),
				URLQueryItem(name: "choose_first", value: "true")
			])

		standardSend(url: url, resultType: FeedWranglerSubscriptionResult.self) { result in
			switch result {
			case .success(let (_, results)):
				if let results = results {
					if let error = results.error {
						completion(.failure(FeedWranglerError.general(message: error)))
					} else {
						completion(.success(results.feed))
					}
				} else {
					completion(.failure(FeedWranglerError.general(message: "No feed found")))
				}
				

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func renameSubscription(feedID: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("subscriptions/rename_feed")
			.appendingQueryItems([
				URLQueryItem(name: "feed_id", value: feedID),
				URLQueryItem(name: "feed_name", value: newName),
			])
		
		standardSend(url: url, resultType: FeedWranglerSubscriptionsRequest.self) { result in
			switch result {
			case .success:
				completion(.success(()))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func removeSubscription(feedID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("subscriptions/remove_feed")
			.appendingQueryItem(URLQueryItem(name: "feed_id", value: feedID))
		
		standardSend(url: url, resultType: FeedWranglerGenericResult.self) { result in
			switch result {
			case .success:
				completion(.success(()))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	// MARK: FeedItems
	func retrieveEntries(articleIDs: [String], completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		let IDs = articleIDs.joined(separator: ",")
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("feed_items/get")
			.appendingQueryItem(URLQueryItem(name: "feed_item_ids", value: IDs))
		
		standardSend(url: url, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func retrieveFeedItems(page: Int = 0, feed: WebFeed? = nil, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		let queryItems = [
			URLQueryItem(name: "read", value: "false"),
			URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
			feed.map { URLQueryItem(name: "feed_id", value: $0.webFeedID) }
		].compactMap { $0 }
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("feed_items/list")
			.appendingQueryItems(queryItems)

		standardSend(url: url, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveUnreadFeedItems(page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("feed_items/list")
			.appendingQueryItems([
				URLQueryItem(name: "read", value: "false"),
				URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
			])
		
		standardSend(url: url, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveAllUnreadFeedItems(foundItems: [FeedWranglerFeedItem] = [], page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		retrieveUnreadFeedItems(page: page) { result in
			switch result {
			case .success(let newItems):
				if newItems.count > 0 {
					self.retrieveAllUnreadFeedItems(foundItems: foundItems + newItems, page: (page + 1), completion: completion)
				} else {
					completion(.success(foundItems + newItems))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveStarredFeedItems(page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("feed_items/list")
			.appendingQueryItems([
				URLQueryItem(name: "starred", value: "true"),
				URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
			])
		
		standardSend(url: url, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveAllStarredFeedItems(foundItems: [FeedWranglerFeedItem] = [], page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		retrieveStarredFeedItems(page: page) { result in
			switch result {
			case .success(let newItems):
				if newItems.count > 0 {
					self.retrieveAllStarredFeedItems(foundItems: foundItems + newItems, page: (page + 1), completion: completion)
				} else {
					completion(.success(foundItems + newItems))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func updateArticleStatus(_ articleID: String, _ statuses: [SyncStatus], completion: @escaping () -> Void) {
		
		var queryItems = statuses.compactMap { status -> URLQueryItem? in
			switch status.key {
			case .read:
				return URLQueryItem(name: "read", value: status.flag.description)
				
			case .starred:
				return URLQueryItem(name: "starred", value: status.flag.description)
			}
		}
		queryItems.append(URLQueryItem(name: "feed_item_id", value: articleID))
		let url = FeedWranglerConfig.clientURL
			.appendingPathComponent("feed_items/update")
			.appendingQueryItems(queryItems)
					
		standardSend(url: url, resultType: FeedWranglerGenericResult.self) { result in
			completion()
		}
	}
	
	private func standardSend<R: Decodable>(url: URL?, resultType: R.Type, completion: @escaping (Result<(HTTPURLResponse, R?), Error>) -> Void) {
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}
		let request = URLRequest(url: callURL, credentials: credentials)
		
		transport.send(request: request, resultType: resultType, completion: completion)
	}

}
