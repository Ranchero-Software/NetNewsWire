//
//  AddWebFeedIntentHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Intents
import Account

public class AddWebFeedIntentHandler: NSObject, AddWebFeedIntentHandling {

	override init() {
		super.init()
		DispatchQueue.main.sync {
			AccountManager.shared = AccountManager()
		}
	}
	
	public func resolveUrl(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedUrlResolutionResult) -> Void) {
		guard let url = intent.url else {
			completion(.unsupported(forReason: .required))
			return
		}
		completion(.success(with: url))
	}
	
	public func provideAccountNameOptions(for intent: AddWebFeedIntent, with completion: @escaping ([String]?, Error?) -> Void) {
		DispatchQueue.main.async {
			let accountNames = AccountManager.shared.activeAccounts.compactMap { $0.nameForDisplay }
			completion(accountNames, nil)
		}
	}
	
	public func resolveAccountName(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedAccountNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName else {
			completion(AddWebFeedAccountNameResolutionResult.notRequired())
			return
		}
		DispatchQueue.main.async {
			if AccountManager.shared.findActiveAccount(forDisplayName: accountName) == nil {
				completion(.unsupported(forReason: .invalid))
			} else {
				completion(.success(with: accountName))
			}
		}
	}
	
	public func provideFolderNameOptions(for intent: AddWebFeedIntent, with completion: @escaping ([String]?, Error?) -> Void) {
		DispatchQueue.main.async {
			guard let accountName = intent.accountName, let account = AccountManager.shared.findActiveAccount(forDisplayName: accountName) else {
				completion([String](), nil)
				return
			}
			
			let folderNames = account.folders?.map { $0.nameForDisplay }
			completion(folderNames, nil)
		}
	}
	
	public func resolveFolderName(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedFolderNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName, let folderName = intent.folderName else {
			completion(AddWebFeedFolderNameResolutionResult.notRequired())
			return
		}
		
		DispatchQueue.main.async {
			guard let account = AccountManager.shared.findActiveAccount(forDisplayName: accountName) else {
				completion(.unsupported(forReason: .invalid))
				return
			}
			if account.findFolder(withDisplayName: folderName) == nil {
				completion(.unsupported(forReason: .invalid))
			} else {
				completion(.success(with: folderName))
			}
			return
		}
	}
	
	public func handle(intent: AddWebFeedIntent, completion: @escaping (AddWebFeedIntentResponse) -> Void) {
		guard let url = intent.url else {
			completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}
		
		DispatchQueue.main.async {
			
			let account: Account? = {
				if let accountName = intent.accountName {
					return AccountManager.shared.findActiveAccount(forDisplayName: accountName)
				} else {
					return AccountManager.shared.sortedActiveAccounts.first
				}
			}()
			
			guard let validAccount = account else {
				completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
				return
			}
			
			let container: Container? = {
				if let folderName = intent.folderName {
					return validAccount.findFolder(withDisplayName: folderName)
				} else {
					return validAccount
				}
			}()
			
			guard let validContainer = container else {
				completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
				return
			}

			validAccount.createWebFeed(url: url.absoluteString, name: nil, container: validContainer) { result in
				switch result {
				case .success:
					AccountManager.shared.suspendNetworkAll()
					AccountManager.shared.suspendDatabaseAll()
					completion(AddWebFeedIntentResponse(code: .success, userActivity: nil))
				case .failure(let error):
					switch error {
					case AccountError.createErrorNotFound:
						completion(AddWebFeedIntentResponse(code: .feedNotFound, userActivity: nil))
					case AccountError.createErrorAlreadySubscribed:
						completion(AddWebFeedIntentResponse(code: .alreadySubscribed, userActivity: nil))
					default:
						completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
					}
				}
			}
		}
		
	}
	
}
