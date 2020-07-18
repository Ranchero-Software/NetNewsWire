//
//  InspectorModel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import UserNotifications
import RSCore
import Account
#if os(macOS)
import AppKit
#else
import UIKit
#endif


class InspectorModel: ObservableObject {
	
	// Global Inspector Variables
	@Published var editedName: String = ""
	@Published var shouldUpdate: Bool = false
	
	// Account Inspector Variables
	@Published var notificationSettings: UNNotificationSettings?
	@Published var notifyAboutNewArticles: Bool = false {
		didSet {
			updateNotificationSettings()
		}
	}
	@Published var alwaysShowReaderView: Bool = false {
		didSet {
			selectedWebFeed?.isArticleExtractorAlwaysOn = alwaysShowReaderView
		}
	}
	@Published var accountIsActive: Bool = false {
		didSet {
			selectedAccount?.isActive = accountIsActive 
		}
	}
	@Published var showHomePage: Bool = false // iOS only
	
	// Private Variables
	private let centre = UNUserNotificationCenter.current()
	private var selectedWebFeed: WebFeed?
	private var selectedFolder: Folder?
	private var selectedAccount: Account?
	
	init() {
		getNotificationSettings()
	}
	
	func getNotificationSettings() {
		centre.getNotificationSettings { (settings) in
			DispatchQueue.main.async {
				self.notificationSettings = settings
				if settings.authorizationStatus == .authorized {
					#if os(macOS)
					NSApplication.shared.registerForRemoteNotifications()
					#else
					UIApplication.shared.registerForRemoteNotifications()
					#endif
				}
			}
		}
	}
	
	func configure(with feed: WebFeed) {
		selectedWebFeed = feed
		notifyAboutNewArticles = selectedWebFeed?.isNotifyAboutNewArticles ?? false
		alwaysShowReaderView = selectedWebFeed?.isArticleExtractorAlwaysOn ?? false
		editedName = feed.nameForDisplay
	}
	
	func configure(with folder: Folder) {
		selectedFolder = folder
		editedName = folder.nameForDisplay
	}
	
	func configure(with account: Account) {
		selectedAccount = account
		editedName = account.nameForDisplay
		accountIsActive = account.isActive
	}
	
	func updateNotificationSettings() {
		guard let feed = selectedWebFeed,
			  let settings = notificationSettings
		else { return }
		if settings.authorizationStatus == .denied {
			notifyAboutNewArticles = false
		} else if settings.authorizationStatus == .authorized {
			feed.isNotifyAboutNewArticles = notifyAboutNewArticles
		} else {
			UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .sound, .alert]) { [weak self] (granted, error) in
				self?.updateNotificationSettings()
				if granted {
					DispatchQueue.main.async {
						self?.selectedWebFeed!.isNotifyAboutNewArticles = self?.notifyAboutNewArticles
						#if os(macOS)
						NSApplication.shared.registerForRemoteNotifications()
						#else
						UIApplication.shared.registerForRemoteNotifications()
						#endif
					}
				} else {
					DispatchQueue.main.async {
						self?.notifyAboutNewArticles = false
					}
				}
			}
		}
	}
	
	
}

