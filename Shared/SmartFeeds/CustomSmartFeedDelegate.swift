//
//  CustomSmartFeedDelegate.swift
//  NetNewsWire
//
//  Created by Mateusz on 18/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import ArticlesDatabase
import Account

struct CustomSmartFeedDelegate: SmartFeedDelegate {
	let feedName: String
	let conjunction: Bool
	let expressions: [CustomSmartFeedExpression]

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: TodayFeedDelegate.self))
	}

	var nameForDisplay: String { feedName }
	var fetchType: FetchType {
		let clause = expressions.query(conjunction: conjunction)
		let parameters = expressions.parameters
		return .customSmartFeed(clause: clause, parameters: parameters)
	}
	var smallIcon: IconImage? {
		return AppImage.customSmartFeed
	}

	func fetchUnreadCount(for account: Account, completion: @escaping SingleUnreadCountCompletionBlock) {
		let clause = expressions.query(conjunction: conjunction)
		let parameters = expressions.parameters
		account.fetchUnreadCountForCustomSmartFeed(clause, parameters, completion)
	}
}
