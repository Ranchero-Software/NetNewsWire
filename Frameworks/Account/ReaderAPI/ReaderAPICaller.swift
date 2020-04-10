//
//  ReaderAPICaller.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

enum CreateReaderAPISubscriptionResult {
	case created(ReaderAPISubscription)
	case alreadySubscribed
	case notFound
}

final class ReaderAPICaller: NSObject {
	
	struct ConditionalGetKeys {
		static let subscriptions = "subscriptions"
		static let tags = "tags"
		static let taggings = "taggings"
		static let icons = "icons"
		static let unreadEntries = "unreadEntries"
		static let starredEntries = "starredEntries"
	}
	
	enum ReaderState: String {
		case read = "user/-/state/com.google/read"
		case starred = "user/-/state/com.google/starred"
	}
	
	enum ReaderStreams: String {
		case readingList = "user/-/state/com.google/reading-list"
	}
	
	enum ReaderAPIEndpoints: String {
		case login = "/accounts/ClientLogin"
		case token = "/reader/api/0/token"
		case disableTag = "/reader/api/0/disable-tag"
		case renameTag = "/reader/api/0/rename-tag"
		case tagList = "/reader/api/0/tag/list"
		case subscriptionList = "/reader/api/0/subscription/list"
		case subscriptionEdit = "/reader/api/0/subscription/edit"
		case subscriptionAdd = "/reader/api/0/subscription/quickadd"
		case contents = "/reader/api/0/stream/items/contents"
		case itemIds = "/reader/api/0/stream/items/ids"
		case editTag = "/reader/api/0/edit-tag"
	}
	
	private var transport: Transport!
	
	var credentials: Credentials?
	private var accessToken: String?
	
	weak var accountMetadata: AccountMetadata?

	var server: String? {
		get {
			return APIBaseURL?.host
		}
	}
	
	private var APIBaseURL: URL? {
		get {
			guard let accountMetadata = accountMetadata else {
				return nil
			}
	
			return accountMetadata.endpointURL
		}
	}
	
	
	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func cancelAll() {
		transport.cancelAll()
	}
	
	func validateCredentials(endpoint: URL, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		guard let credentials = credentials else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let request = URLRequest(url: endpoint.appendingPathComponent(ReaderAPIEndpoints.login.rawValue), credentials: credentials)

		transport.send(request: request) { result in
			switch result {
			case .success(let (_, data)):
				guard let resultData = data else {
					completion(.failure(TransportError.noData))
					break
				}
				
				// Convert the return data to UTF8 and then parse out the Auth token
				guard let rawData = String(data: resultData, encoding: .utf8) else {
					completion(.failure(TransportError.noData))
					break
				}
				
				var authData: [String: String] = [:]
				rawData.split(separator: "\n").forEach({ (line: Substring) in
					let items = line.split(separator: "=").map{String($0)}
					authData[items[0]] = items[1]
				})
				
				guard let authString = authData["Auth"] else {
					completion(.failure(CredentialsError.incompleteCredentials))
					break
				}
				
				// Save Auth Token for later use
				self.credentials = Credentials(type: .readerAPIKey, username: credentials.username, secret: authString)
				
				completion(.success(self.credentials))
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func requestAuthorizationToken(endpoint: URL, completion: @escaping (Result<String, Error>) -> Void) {
		// If we have a token already, use it
		if let accessToken = accessToken {
			completion(.success(accessToken))
			return
		}
		
		// Otherwise request one.
		guard let credentials = credentials else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let request = URLRequest(url: endpoint.appendingPathComponent(ReaderAPIEndpoints.token.rawValue), credentials: credentials)
		
		transport.send(request: request) { result in
			switch result {
			case .success(let (_, data)):
				guard let resultData = data else {
					completion(.failure(TransportError.noData))
					break
				}
				
				// Convert the return data to UTF8 and then parse out the Auth token
				guard let accessToken = String(data: resultData, encoding: .utf8) else {
					completion(.failure(TransportError.noData))
					break
				}
				
				self.accessToken = accessToken
				completion(.success(accessToken))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	
	func retrieveTags(completion: @escaping (Result<[ReaderAPITag]?, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.tagList.rawValue)
			.appendingQueryItem(URLQueryItem(name: "output", value: "json"))
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.tags]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: ReaderAPITagContainer.self) { result in
			
			switch result {
			case .success(let (response, wrapper)):
				self.storeConditionalGet(key: ConditionalGetKeys.tags, headers: response.allHeaderFields)
				completion(.success(wrapper?.tags))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func renameTag(oldName: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.renameTag.rawValue), credentials: self.credentials)
				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let oldTagName = "user/-/label/\(oldName)"
				let newTagName = "user/-/label/\(newName)"
				let postData = "T=\(token)&s=\(oldTagName)&dest=\(newTagName)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func deleteTag(name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.disableTag.rawValue), credentials: self.credentials)
				
				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let tagName = "user/-/label/\(name)"
				let postData = "T=\(token)&s=\(tagName)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	func retrieveSubscriptions(completion: @escaping (Result<[ReaderAPISubscription]?, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.subscriptionList.rawValue)
			.appendingQueryItem(URLQueryItem(name: "output", value: "json"))
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.subscriptions]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: ReaderAPISubscriptionContainer.self) { result in
			
			switch result {
			case .success(let (response, container)):
				self.storeConditionalGet(key: ConditionalGetKeys.subscriptions, headers: response.allHeaderFields)
				completion(.success(container?.subscriptions))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func createSubscription(url: String, completion: @escaping (Result<CreateReaderAPISubscriptionResult, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		guard let url = URL(string: url) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
		FeedFinder.find(url: url) { result in
			
			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					let url = URL(string: bestFeedSpecifier.urlString) else {
						completion(.failure(AccountError.createErrorNotFound))
						return
				}
				self.requestAuthorizationToken(endpoint: baseURL) { (result) in
					switch result {
					case .success(let token):
						let url = baseURL
							.appendingPathComponent(ReaderAPIEndpoints.subscriptionAdd.rawValue)
							.appendingQueryItem(URLQueryItem(name: "quickadd", value: url.absoluteString))
		
						guard let callURL = url else {
							completion(.failure(TransportError.noURL))
							return
						}
		
						var request = URLRequest(url: callURL, credentials: self.credentials)
						request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
						request.httpMethod = "POST"
		
						let postData = "T=\(token)".data(using: String.Encoding.utf8)
		
						self.transport.send(request: request, method: HTTPMethod.post, data: postData!, resultType: ReaderAPIQuickAddResult.self, completion: { (result) in
							switch result {
							case .success(let (_, subResult)):
		
								switch subResult?.numResults {
								case 0:
									completion(.success(.alreadySubscribed))
								default:
									// We have a feed ID but need to get feed information
									guard let streamId = subResult?.streamId else {
										completion(.failure(AccountError.createErrorNotFound))
										return
									}
		
									// There is no call to get a single subscription entry, so we get them all,
									// look up the one we just subscribed to and return that
									self.retrieveSubscriptions(completion: { (result) in
										switch result {
										case .success(let subscriptions):
											guard let subscriptions = subscriptions else {
												completion(.failure(AccountError.createErrorNotFound))
												return
											}
		
											let newStreamId = "feed/\(streamId)"
		
											guard let subscription = subscriptions.first(where: { (sub) -> Bool in
												sub.feedID == newStreamId
											}) else {
												completion(.failure(AccountError.createErrorNotFound))
												return
											}
		
											completion(.success(.created(subscription)))
		
										case .failure(let error):
											completion(.failure(error))
										}
									})
									}
							case .failure(let error):
								completion(.failure(error))
							}
						})
		
		
					case .failure(let error):
						completion(.failure(error))
					}
				}
				
				
				
			case .failure:
				completion(.failure(AccountError.createErrorNotFound))
			}
			
		}
//
	}
	
	func renameSubscription(subscriptionID: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), credentials: self.credentials)
				
				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let postData = "T=\(token)&s=\(subscriptionID)&ac=edit&t=\(newName)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func deleteSubscription(subscriptionID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), credentials: self.credentials)

				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let postData = "T=\(token)&s=\(subscriptionID)&ac=unsubscribe".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func createTagging(subscriptionID: String, tagName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), credentials: self.credentials)
				
				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let tagName = "user/-/label/\(tagName)"
				let postData = "T=\(token)&s=\(subscriptionID)&ac=edit&a=\(tagName)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}

	func deleteTagging(subscriptionID: String, tagName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.subscriptionEdit.rawValue), credentials: self.credentials)
				
				
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				let tagName = "user/-/label/\(tagName)"
				let postData = "T=\(token)&s=\(subscriptionID)&ac=edit&r=\(tagName)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
						break
					case .failure(let error):
						completion(.failure(error))
						break
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveEntries(articleIDs: [String], completion: @escaping (Result<([ReaderAPIEntry]?), Error>) -> Void) {
		
		guard !articleIDs.isEmpty else {
			completion(.success(([ReaderAPIEntry]())))
			return
		}
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				// Do POST asking for data about all the new articles
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.contents.rawValue), credentials: self.credentials)
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				// Get ids from above into hex representation of value
				let idsToFetch = articleIDs.map({ (reference) -> String in
					return "i=\(reference)"
				}).joined(separator:"&")
				
				let postData = "T=\(token)&output=json&\(idsToFetch)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, data: postData!, resultType: ReaderAPIEntryWrapper.self, completion: { (result) in
					switch result {
					case .success(let (_, entryWrapper)):
						guard let entryWrapper = entryWrapper else {
							completion(.failure(ReaderAPIAccountDelegateError.invalidResponse))
							return
						}
						
						completion(.success((entryWrapper.entries)))
					case .failure(let error):
						completion(.failure(error))
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}

	}

	func retrieveEntries(webFeedID: String, completion: @escaping (Result<([ReaderAPIEntry]?, String?), Error>) -> Void) {
		
		let since = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.itemIds.rawValue)
			.appendingQueryItems([
				URLQueryItem(name: "s", value: webFeedID),
				URLQueryItem(name: "ot", value: String(since.timeIntervalSince1970)),
				URLQueryItem(name: "output", value: "json")
			])
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: nil)
		
		transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self) { result in
			
			switch result {
			case .success(let (_, unreadEntries)):
				
				guard let itemRefs = unreadEntries?.itemRefs else {
					completion(.success(([], nil)))
					return
				}
				
				let itemIds = itemRefs.map { (reference) -> String in
					// Convert the IDs to the (stupid) Google Hex Format
					let idValue = Int(reference.itemId)!
					return String(idValue, radix: 16, uppercase: false)
				}
				
				self.retrieveEntries(articleIDs: itemIds) { (results) in
					switch results {
					case .success(let entries):
						completion(.success((entries,nil)))
					case .failure(let error):
						completion(.failure(error))
					}
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}

	func retrieveEntries(completion: @escaping (Result<([ReaderAPIEntry]?, String?, Int?), Error>) -> Void) {
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let since: Date = {
			if let lastArticleFetch = self.accountMetadata?.lastArticleFetchStartTime {
				return lastArticleFetch
			} else {
				return Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
			}
		}()
		
		let sinceString = since.timeIntervalSince1970
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.itemIds.rawValue)
			.appendingQueryItems([
				URLQueryItem(name: "o", value: String(sinceString)),
				URLQueryItem(name: "n", value: "10000"),
				URLQueryItem(name: "output", value: "json"),
				URLQueryItem(name: "xt", value: ReaderState.read.rawValue),
				URLQueryItem(name: "s", value: ReaderStreams.readingList.rawValue)
			])
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.unreadEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		self.transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self) { result in
			
			switch result {
			case .success(let (_, entries)):
				
				guard let entries = entries else {
					completion(.failure(ReaderAPIAccountDelegateError.invalidResponse))
					return
				}
				
				self.requestAuthorizationToken(endpoint: baseURL) { (result) in
					switch result {
					case .success(let token):
						// Do POST asking for data about all the new articles
						var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.contents.rawValue), credentials: self.credentials)
						request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
						request.httpMethod = "POST"
						
						// Get ids from above into hex representation of value
						let idsToFetch = entries.itemRefs.map({ (reference) -> String in
							let idValue = Int(reference.itemId)!
							let idHexString = String(idValue, radix: 16, uppercase: false)
							return "i=\(idHexString)"
						}).joined(separator:"&")
						
						let postData = "T=\(token)&output=json&\(idsToFetch)".data(using: String.Encoding.utf8)

						self.transport.send(request: request, method: HTTPMethod.post, data: postData!, resultType: ReaderAPIEntryWrapper.self, completion: { (result) in
							switch result {
							case .success(let (response, entryWrapper)):
								guard let entryWrapper = entryWrapper else {
									completion(.failure(ReaderAPIAccountDelegateError.invalidResponse))
									return
								}
								
								let dateInfo = HTTPDateInfo(urlResponse: response)
								self.accountMetadata?.lastArticleFetchStartTime = dateInfo?.date
								self.accountMetadata?.lastArticleFetchEndTime = Date()
								
								completion(.success((entryWrapper.entries, nil, nil)))
							case .failure(let error):
								completion(.failure(error))
							}
						})
						
						
					case .failure(let error):
						completion(.failure(error))
					}
				}
				
			case .failure(let error):
				self.accountMetadata?.lastArticleFetchStartTime = nil
				completion(.failure(error))
			}
			
		}
	}
	
	func retrieveEntries(page: String, completion: @escaping (Result<([ReaderAPIEntry]?, String?), Error>) -> Void) {
		
		guard let url = URL(string: page)?.appendingQueryItem(URLQueryItem(name: "mode", value: "extended")) else {
			completion(.success((nil, nil)))
			return
		}
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request, resultType: [ReaderAPIEntry].self) { result in
			
			switch result {
			case .success(let (response, entries)):
				
				let pagingInfo = HTTPLinkPagingInfo(urlResponse: response)
				completion(.success((entries, pagingInfo.nextPage)))

			case .failure(let error):
				self.accountMetadata?.lastArticleFetchStartTime = nil
				completion(.failure(error))
			}
			
		}
		
	}

	func retrieveUnreadEntries(completion: @escaping (Result<[Int]?, Error>) -> Void) {
		
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.itemIds.rawValue)
			.appendingQueryItems([
				URLQueryItem(name: "s", value: ReaderStreams.readingList.rawValue),
				URLQueryItem(name: "n", value: "10000"),
				URLQueryItem(name: "xt", value: ReaderState.read.rawValue),
				URLQueryItem(name: "output", value: "json")
			])
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}

		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.unreadEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self) { result in
			
			switch result {
			case .success(let (response, unreadEntries)):
				
				guard let itemRefs = unreadEntries?.itemRefs else {
					completion(.success([]))
					return
				}
				
				let itemIds = itemRefs.map{ Int($0.itemId)! }
				
				self.storeConditionalGet(key: ConditionalGetKeys.unreadEntries, headers: response.allHeaderFields)
				completion(.success(itemIds))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	
	func updateStateToEntries(entries: [Int], state: ReaderState, add: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		self.requestAuthorizationToken(endpoint: baseURL) { (result) in
			switch result {
			case .success(let token):
				// Do POST asking for data about all the new articles
				var request = URLRequest(url: baseURL.appendingPathComponent(ReaderAPIEndpoints.editTag.rawValue), credentials: self.credentials)
				request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				// Get ids from above into hex representation of value
				let idsToFetch = entries.map({ (idValue) -> String in
					let idHexString = String(format: "%.16llx", idValue)
					return "i=\(idHexString)"
				}).joined(separator:"&")
				
				let actionIndicator = add ? "a" : "r"
				
				let postData = "T=\(token)&\(idsToFetch)&\(actionIndicator)=\(state.rawValue)".data(using: String.Encoding.utf8)
				
				self.transport.send(request: request, method: HTTPMethod.post, payload: postData!, completion: { (result) in
					switch result {
					case .success:
						completion(.success(()))
					case .failure(let error):
						completion(.failure(error))
					}
				})
				
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func createUnreadEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		updateStateToEntries(entries: entries, state: .read, add: false, completion: completion)
	}
	
	func deleteUnreadEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		updateStateToEntries(entries: entries, state: .read, add: true, completion: completion)

	}
	
	func createStarredEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		updateStateToEntries(entries: entries, state: .starred, add: true, completion: completion)
		
	}
	
	func deleteStarredEntries(entries: [Int], completion: @escaping (Result<Void, Error>) -> Void) {
		updateStateToEntries(entries: entries, state: .starred, add: false, completion: completion)
	}
	
	func retrieveStarredEntries(completion: @escaping (Result<[Int]?, Error>) -> Void) {
		guard let baseURL = APIBaseURL else {
			completion(.failure(CredentialsError.incompleteCredentials))
			return
		}
		
		let url = baseURL
			.appendingPathComponent(ReaderAPIEndpoints.itemIds.rawValue)
			.appendingQueryItems([
				URLQueryItem(name: "s", value: "user/-/state/com.google/starred"),
				URLQueryItem(name: "n", value: "10000"),
				URLQueryItem(name: "output", value: "json")
			])
		
		guard let callURL = url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let conditionalGet = accountMetadata?.conditionalGetInfo[ConditionalGetKeys.starredEntries]
		let request = URLRequest(url: callURL, credentials: credentials, conditionalGet: conditionalGet)
		
		transport.send(request: request, resultType: ReaderAPIReferenceWrapper.self) { result in
			
			switch result {
			case .success(let (response, unreadEntries)):
				
				guard let itemRefs = unreadEntries?.itemRefs else {
					completion(.success([]))
					return
				}
				
				let itemIds = itemRefs.map{ Int($0.itemId)! }
				
				self.storeConditionalGet(key: ConditionalGetKeys.starredEntries, headers: response.allHeaderFields)
				completion(.success(itemIds))
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
		
	}
	

	
}

// MARK: Private

extension ReaderAPICaller {
	
	func storeConditionalGet(key: String, headers: [AnyHashable : Any]) {
		if var conditionalGet = accountMetadata?.conditionalGetInfo {
			conditionalGet[key] = HTTPConditionalGetInfo(headers: headers)
			accountMetadata?.conditionalGetInfo = conditionalGet
		}
	}
}
