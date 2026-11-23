//
//  SidebarSettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SidebarSettingsView: View {

	@State private var model = SidebarSettingsModel()

	var body: some View {
		List {
			Section {
				Toggle(String(localized: "Show Feed Icons", comment: "Show Feed Icons"), isOn: Binding(get: { model.showFeedIcons }, set: { AppDefaults.sidebarShowsIcons = $0 }))
			}
			Section(String(localized: "Smart Feeds", comment: "Smart Feeds group title")) {
				Toggle(String(localized: "Show Today", comment: "Show Today"), isOn: Binding(get: { model.showToday }, set: { AppDefaults.showTodayFeed = $0 }))
				Toggle(String(localized: "Show All Unread", comment: "Show All Unread"), isOn: Binding(get: { model.showAllUnread }, set: { AppDefaults.showUnreadFeed = $0 }))
				Toggle(String(localized: "Show Starred", comment: "Show Starred"), isOn: Binding(get: { model.showStarred }, set: { AppDefaults.showStarredFeed = $0 }))
			}
		}
		.settingsAccentTint()
		.navigationTitle(String(localized: "Sidebar", comment: "Sidebar"))
	}
}

/// Tracks the Sidebar settings in AppDefaults, updating when they change.
@MainActor @Observable final class SidebarSettingsModel {

	private(set) var showFeedIcons = AppDefaults.sidebarShowsIcons
	private(set) var showToday = AppDefaults.showTodayFeed
	private(set) var showAllUnread = AppDefaults.showUnreadFeed
	private(set) var showStarred = AppDefaults.showStarredFeed

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarShowsIconsDidChange(_:)), name: .sidebarShowsIconsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarSmartFeedsVisibilityDidChange(_:)), name: .sidebarSmartFeedsVisibilityDidChange, object: nil)
	}

	@objc func handleSidebarShowsIconsDidChange(_ notification: Notification) {
		showFeedIcons = AppDefaults.sidebarShowsIcons
	}

	@objc func handleSidebarSmartFeedsVisibilityDidChange(_ notification: Notification) {
		showToday = AppDefaults.showTodayFeed
		showAllUnread = AppDefaults.showUnreadFeed
		showStarred = AppDefaults.showStarredFeed
	}
}
