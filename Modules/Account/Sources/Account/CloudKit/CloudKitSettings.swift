//
//  CloudKitSettings.swift
//  Account
//
//  Created by Brent Simmons on 3/18/26.
//

import Foundation

protocol CloudKitSettings {
	var syncArticleContentForUnreadArticles: Bool { get }
}

extension CloudKitAccountDelegate: CloudKitSettings {

	var syncArticleContentForUnreadArticles: Bool {
		CloudKitAccountDelegate.syncArticleContentForUnreadArticles
	}
}
