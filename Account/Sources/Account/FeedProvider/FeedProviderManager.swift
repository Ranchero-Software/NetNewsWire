//
//  FeedProviderManager.swift
//  Account
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedProviderManagerDelegate: AnyObject {
	var activeFeedProviders: [FeedProvider] { get }
}

public final class FeedProviderManager {
	
	public static let shared = FeedProviderManager()
	public weak var delegate: FeedProviderManagerDelegate?
	
	public func best(for offered: URLComponents) -> FeedProvider? {
		if let owner = feedProviderMatching(offered, ability: .owner) {
			return owner
		}
		return feedProviderMatching(offered, ability: .available)
	}
	
}

private extension FeedProviderManager {
	
	func feedProviderMatching(_ offered: URLComponents, ability: FeedProviderAbility) -> FeedProvider? {
		if let delegate = delegate {
			for feedProvider in delegate.activeFeedProviders {
				if feedProvider.ability(offered) == ability {
					return feedProvider
				}
			}
		}
		return nil
	}
	
}
