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

struct NewArticleNotificationsView: View {
	
	@State private var activeAccounts = AccountManager.shared.sortedActiveAccounts
    
	var body: some View {
		List {
			ForEach(activeAccounts, id: \.accountID) { account in
				Section(header: Text(account.nameForDisplay)) {
					ForEach(sortedWebFeedsForAccount(account), id: \.webFeedID) { feed in
						notificationToggle(feed)
					}
				}
			}
			.navigationTitle(Text("New Article Notifications"))
			.navigationBarTitleDisplayMode(.inline)
			.onReceive(NotificationCenter.default.publisher(for: .WebFeedIconDidBecomeAvailable)) { _ in
				activeAccounts = AccountManager.shared.sortedActiveAccounts
			}
		}
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
    }
	
	
	private func sortedWebFeedsForAccount(_ account: Account) -> [WebFeed] {
		return Array(account.flattenedWebFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	private func notificationToggle(_ webfeed: WebFeed) -> some View {
		HStack {
			Image(uiImage: IconImageCache.shared.imageFor(webfeed.feedID!)!.image)
				.resizable()
				.frame(width: 25, height: 25)
				.cornerRadius(4)
			
			Text(webfeed.nameForDisplay)
			Spacer()
			Toggle("", isOn: Binding(
				get: { webfeed.isNotifyAboutNewArticles ?? false },
				set: { webfeed.isNotifyAboutNewArticles = $0 }))
		}
		
	}
}

struct NewArticleNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NewArticleNotificationsView()
    }
}
