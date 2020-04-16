//
//  FeedProviderManager.swift
//  Account
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedProviderManagerDelegate: class {
	var activeFeedProviders: [FeedProvider] { get }
}

public final class FeedProviderManager {
	
	public static let shared = FeedProviderManager()
	public weak var delegate: FeedProviderManagerDelegate?
	
	public func best(for offered: URLComponents, with username: String?) -> FeedProvider? {
		if let owner = feedProviderMatching(offered, forUsername: username, ability: .owner) {
			return owner
		}
		return feedProviderMatching(offered, forUsername: username, ability: .available)
	}
	
}

private extension FeedProviderManager {
	
	func feedProviderMatching(_ offered: URLComponents, forUsername username: String?, ability: FeedProviderAbility) -> FeedProvider? {
		if let delegate = delegate {
			for feedProvider in delegate.activeFeedProviders {
				if feedProvider.ability(offered, forUsername: username) == ability {
					return feedProvider
				}
			}
		}
		return nil
	}
	
}
