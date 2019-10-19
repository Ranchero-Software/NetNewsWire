//
//  AddFeedIntentHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Intents
import Account

public class AddFeedIntentHandler: NSObject, AddFeedIntentHandling {
	
	override init() {
		super.init()
		DispatchQueue.main.sync {
			AccountManager.shared = AccountManager()
		}
	}
	
	public func resolveUrl(for intent: AddFeedIntent, with completion: @escaping (AddFeedUrlResolutionResult) -> Void) {
		guard let url = intent.url else {
			completion(.unsupported(forReason: .required))
			return
		}
		completion(.success(with: url))
	}
	
	public func handle(intent: AddFeedIntent, completion: @escaping (AddFeedIntentResponse) -> Void) {
		guard let url = intent.url else {
			completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}
		
		DispatchQueue.main.async {
			guard let account = AccountManager.shared.activeAccounts.first else {
				completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
				return
			}
			
			account.createFeed(url: url.absoluteString, name: nil, container: account) { result in
				switch result {
				case .success:
					completion(AddFeedIntentResponse(code: .success, userActivity: nil))
				case .failure:
					completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
				}
			}
		}
		
	}
	
}
