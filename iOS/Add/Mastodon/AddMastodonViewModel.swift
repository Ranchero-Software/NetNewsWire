//
//  AddMastodonViewModel.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore

enum MastodonFeedType: CustomStringConvertible {
	case user, tag
	
	var description: String {
		switch self {
		case .user:
			return NSLocalizedString("Follow a User", comment: "Mastodon User")
		case .tag:
			return NSLocalizedString("Follow a Tag", comment: "Mastodon Tag")
		}
	}
	
	var shortDescription: String  {
		switch self {
		case .user:
			return NSLocalizedString("User", comment: "User")
		case .tag:
			return NSLocalizedString("Tag", comment: "Tag")
		}
	}
}

/// The `AddMastodonViewModel` inherits from `FeedFolderResolver` which
/// is an `ObservableObject` that provides the Feed/Folder picker managements.
///
/// The `AddMastodonViewModel` class includes properties and functions specific to adding
/// Mastodon RSS feeds.
class AddMastodonViewModel: FeedFolderResolver {
	
	@Published var mastodonUserName: String = ""
	@Published var mastodonDomain: String = ""
	@Published var mastodonTag: String = ""
	@Published var showProgressIndicator: Bool = false
	@Published var mastodonFeedType: MastodonFeedType = .user
	
	public var mastdonUrl: URL? {
		if mastodonFeedType == .user {
			let urlString = "https://\(mastodonDomain)/users/\(mastodonUserName).rss"
			if let url = URL(string: urlString) { return url } else { return nil }
		} else {
			let urlString = "https://mastodon.social/tags/\(mastodonTag).rss"
			if let url = URL(string: urlString) { return url } else { return nil }
		}
	}
	
	/// The ability to add Mastodon accounts is disabled when
	/// `showProgressIndicator` is `true` or the provided
	/// user name and domain can't form a valid URL.
	/// - Returns: `Bool`
	func isMastodonDisabled() -> Bool {
		if showProgressIndicator == true { return true }
		if mastodonFeedType == .user {
			if mastodonDomain.trimmingWhitespace.count == 0 { return true }
			if mastodonUserName.trimmingWhitespace.count == 0 { return true }
			let urlString = "https://\(mastodonDomain)/users/\(mastodonUserName).rss"
			if urlString.mayBeURL {
				return false
			} else {
				return true
			}
		} else {
			if mastodonTag.trimmingWhitespace.count == 0 { return true }
			return false
		}
		
	}
	
	@MainActor
	func addMastodonFeedToAccount() async throws {
		showProgressIndicator = true
		
		if let account = accountAndFolderFromContainer(containers[selectedFolderIndex])?.account {
			let container = containers[selectedFolderIndex]
			if let providedURL = mastdonUrl {
				if account.hasWebFeed(withURL: providedURL.absoluteString) {
					showProgressIndicator = false
					throw AddWebFeedError.alreadySubscribed
				}
				
				try await withCheckedThrowingContinuation { continuation in
					account.createWebFeed(url: providedURL.absoluteString, name: nil, container: container, validateFeed: true, completion: { [weak self] result in
						self?.showProgressIndicator = false
						switch result {
						case .success(let feed):
							NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
							continuation.resume()
						case .failure(let error):
							continuation.resume(throwing: error)
						}
					})
				}
			}
		}
	}
	
}
