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


struct NewArticleNotificationsView: View, Logging {
	
	@State private var activeAccounts = AccountManager.shared.sortedActiveAccounts
    
	var body: some View {
		List(activeAccounts, id: \.accountID) { account in
			Section(header: Text(account.nameForDisplay)) {
				ForEach(sortedWebFeedsForAccount(account), id: \.webFeedID) { feed in
					WebFeedToggle(webfeed: feed)
						.id(feed.webFeedID)
				}
			}
			.navigationTitle(Text("navigation.title.new-article-notifications", comment: "New Article Notifications"))
			.navigationBarTitleDisplayMode(.inline)
			
		}
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.onReceive(NotificationCenter.default.publisher(for: .FaviconDidBecomeAvailable)) { notification in
			guard let faviconURLString = notification.userInfo?["faviconURL"] as? String,
				  let faviconHost = URL(string: faviconURLString)?.host else {
				return
			}
			activeAccounts.forEach { account in
				for feed in Array(account.flattenedWebFeeds()) {
					if let feedURLHost = URL(string: feed.url)?.host {
						if faviconHost == feedURLHost {
							feed.objectWillChange.send()
						}
					}
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .WebFeedIconDidBecomeAvailable)) { notification in
			guard let webFeed = notification.userInfo?[UserInfoKey.webFeed] as? WebFeed else { return }
			webFeed.objectWillChange.send()
		}
    }
	
	private func sortedWebFeedsForAccount(_ account: Account) -> [WebFeed] {
		return Array(account.flattenedWebFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	
}

fileprivate struct WebFeedToggle: View {
	
	@ObservedObject var webfeed: WebFeed
	
	var body: some View {
		Toggle(isOn: Binding(
			get: { webfeed.isNotifyAboutNewArticles ?? false },
			set: { webfeed.isNotifyAboutNewArticles = $0 })) {
				Label {
					Text(webfeed.nameForDisplay)
				} icon: {
					Image(uiImage: IconImageCache.shared.imageFor(webfeed.feedID!)!.image)
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
