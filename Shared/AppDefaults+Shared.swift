//
//  AppDefaults+Shared.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/18/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation
import Account

extension AppDefaults {

	static let iCloudSyncArticleContentForUnreadArticles = "iCloudSyncArticleContentForUnreadArticles"

	var iCloudSyncArticleContentForUnreadArticles: Bool {
		get {
			UserDefaults.standard.bool(forKey: Self.iCloudSyncArticleContentForUnreadArticles)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.iCloudSyncArticleContentForUnreadArticles)
		}
	}

	@MainActor func migrateiCloudSyncArticleContentForUnreadArticlesSetting() {
		// iCloudSyncArticleContentForUnreadArticles should be set to false unless
		// the user already has an iCloud account.
		guard UserDefaults.standard.object(forKey: Self.iCloudSyncArticleContentForUnreadArticles) == nil else {
			return
		}
		iCloudSyncArticleContentForUnreadArticles = AccountManager.shared.hasiCloudAccount
	}
}
