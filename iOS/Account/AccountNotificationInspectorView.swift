//
//  AccountNotificationInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 07/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import UserNotifications
import Account

struct AccountNotificationInspectorView: View {
	
	@Environment(\.dismiss) private var dismiss
	@State private var uuid = UUID()
    
	var account: Account!
	
	var body: some View {
		NavigationStack {
			List(account.flattenedFeeds().sorted(by: { a, b in
				a.nameForDisplay < b.nameForDisplay
			}), id: \.feedID) { feed in
				Toggle(isOn: Binding(get: { feed.isNotifyAboutNewArticles ?? false }, set: { feed.isNotifyAboutNewArticles = $0 })) {
					HStack {
						if let img = IconImageCache.shared.imageFor(feed.sidebarItemID!) {
							IconImageView(icon: img)
								.id(uuid)
						} else if let img = feed.smallIcon {
							IconImageView(icon: img)
								.id(uuid)
						}
						Text(verbatim: feed.nameForDisplay)
						Spacer()
					}
				}
				.tint(.accentColor)
			}
			.navigationTitle(Text("New Article Notifications", comment: "New Article Notifications"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						dismiss()
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name.feedIconDidBecomeAvailable)) { _ in
				uuid = UUID()
			}
		}
    }
}

