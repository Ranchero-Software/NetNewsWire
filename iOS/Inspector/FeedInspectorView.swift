//
//  FeedInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 06/06/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import UserNotifications
import RSCore
import Account
import Images

struct FeedInspectorView: View {

	// MARK: Environment
	@Environment(\.dismiss) var dismiss
	@Environment(\.openURL) var openURL

	// MARK: State
	@State private var authorizationStatus: UNAuthorizationStatus?
	@State private var navigationTitle: String?
	@State private var newArticleNotificationEnabled: Bool = false
	
	// MARK: Bindings
	
	// MARK: Constants
	
	// MARK: Variables
	var feed: Feed!
	
	init(feed: Feed) {
		self.feed = feed
	}
	
	// MARK: Views
	
	var body: some View {
		NavigationStack {
			Form {
				Section {
					feedTitle
					newArticleNotificationToggle
					alwaysUseReaderViewToggle
				} header: {
					headerView
				} footer: {
					if authorizationStatus == .denied {
						Text("Notifications are currently disabled. Enable them in Settings.")
							.onTapGesture {
								UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
							}
					}
				}
				
				if feed.homePageURL != nil {
					Section {
						homePageURL
					}
				}
				
				Section {
					feedURL
				}
			}
			.navigationTitle(navigationTitle ?? "")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark")
					}
					.help("Dismiss")
				}
			}
			.onAppear {
				navigationTitle = feed.nameForDisplay
				updateNotificationSettings()
				newArticleNotificationEnabled = feed.newArticleNotificationsEnabled
			}
			.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
				updateNotificationSettings()
			}
		}
    }
	
	private var headerView: some View {
		HStack {
			Spacer()
			if let feedImage = IconImageCache.shared.imageForFeed(feed) {
				IconImageView(icon: feedImage, size: .large)
			}
			Spacer()
		}
	}
	
	private var feedTitle: some View {
		TextField("Feed Title",
				  text: Binding(get: { feed.nameForDisplay } ,
								set: { newTitle in
			let newName = newTitle.isEmpty ? (feed.name ?? NSLocalizedString("Untitled", comment: "Feed name")) : newTitle
			feed.rename(to: newName) { _  in
				self.navigationTitle = newName
			}
		}))
	}
	
	private var newArticleNotificationToggle: some View {
		Toggle(isOn: Binding(get: { feed.newArticleNotificationsEnabled }, set: { newValue in
			feed.newArticleNotificationsEnabled = newValue
		})) {
			Text(feed.notificationDisplayName.capitalized)
		}
		.tint(Color.accentColor)
		.disabled(authorizationStatus != .authorized)
	}
	
	private var alwaysUseReaderViewToggle: some View {
		Toggle(isOn: Binding(get: { feed.readerViewAlwaysEnabled }, set: { newValue in
			feed.readerViewAlwaysEnabled = newValue
		})) {
			Text("Always Use Reader View")
		}
		.tint(Color.accentColor)
		.disabled(AppDefaults.shared.isDeveloperBuild)
	}
	
	private var homePageURL: some View {
		HStack {
			Text(feed.homePageURL ?? "")
			Spacer()
			Image(systemName: "safari")
				.foregroundStyle(Color.accentColor)
		}
		.onTapGesture {
			guard let homePage = feed.homePageURL,
				  let url = URL(string: homePage) else {
				return
			}
			openURL(url)
		}
		.contextMenu {
			Button {
				UIPasteboard.general.string = feed.homePageURL
			} label: {
				Text("Copy Home Page URL")
				Image(systemName: "document.on.document")
			}
		}
	}
	
	private var feedURL: some View {
		HStack {
			Text(feed.url)
		}
		.contextMenu {
			Button {
				UIPasteboard.general.string = feed.url
			} label: {
				Text("Copy Feed URL")
				Image(systemName: "document.on.document")
			}
		}
	}
	
	
	// MARK: Functions
	
	private func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			let updatedAuthorizationStatus = settings.authorizationStatus
			Task { @MainActor in
				self.authorizationStatus = updatedAuthorizationStatus
				if self.authorizationStatus == .authorized {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}
}


