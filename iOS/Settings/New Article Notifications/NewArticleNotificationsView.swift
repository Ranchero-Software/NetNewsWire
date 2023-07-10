//
//  NewArticleNotificationsView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 29/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore


@MainActor struct NewArticleNotificationsView: View, Logging {
	
	@State private var activeAccounts = AccountManager.shared.sortedActiveAccounts
    
	var body: some View {
		List(activeAccounts, id: \.accountID) { account in
			Section(header: Text(account.nameForDisplay)) {
				ForEach(sortedFeedsForAccount(account), id: \.feedID) { feed in
					FeedToggle(feed: feed)
						.id(feed.feedID)
				}
			}
			.navigationTitle(Text("navigation.title.new-article-notifications", comment: "New Article Notifications"))
			.navigationBarTitleDisplayMode(.inline)
			
		}
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.onReceive(NotificationCenter.default.publisher(for: .FaviconDidBecomeAvailable), perform: { notification in
			guard let faviconURLString = notification.userInfo?["faviconURL"] as? String,
				  let faviconHost = URL(string: faviconURLString)?.host else {
				return
			}
			for account in activeAccounts {
				for feed in Array(account.flattenedFeeds()) {
					if let feedURLHost = URL(string: feed.url)?.host {
						if faviconHost == feedURLHost {
							feed.objectWillChange.send()
						}
					}
				}
			}
		})
		.onReceive(NotificationCenter.default.publisher(for: .FeedIconDidBecomeAvailable), perform: { notification in
			guard let feed = notification.userInfo?[UserInfoKey.feed] as? Feed else { return }
			feed.objectWillChange.send()
		})
    }
	
	private func sortedFeedsForAccount(_ account: Account) -> [Feed] {
		return Array(account.flattenedFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	
}

fileprivate struct FeedToggle: View {
	
	@ObservedObject var feed: Feed
	
	var body: some View {
		Toggle(isOn: Binding(
			get: { feed.isNotifyAboutNewArticles ?? false },
			set: { feed.isNotifyAboutNewArticles = $0 })) {
				Label {
					Text(feed.nameForDisplay)
				} icon: {
					Image(uiImage: IconImageCache.shared.imageFor(feed.itemID!)!.image)
						.resizable()
						.frame(width: 25, height: 25)
						.cornerRadius(4)
				}
			}
	}
	
}


struct NewArticleNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NewArticleNotificationsView()
    }
}
