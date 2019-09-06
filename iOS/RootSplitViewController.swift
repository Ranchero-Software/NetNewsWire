//
//  RootSplitViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class RootSplitViewController: UISplitViewController {
	
	var coordinator: SceneCoordinator!
	
	// MARK: Keyboard Shortcuts
	
	@objc func scrollOrGoToNextUnread(_ sender: Any?) {
		coordinator.scrollOrGoToNextUnread()
	}
	
	@objc func goToPreviousUnread(_ sender: Any?) {
		coordinator.selectPrevUnread()
	}
	
	@objc func nextUnread(_ sender: Any?) {
		coordinator.selectNextUnread()
	}
	
	@objc func markRead(_ sender: Any?) {
		coordinator.markAsReadForCurrentArticle()
	}
	
	@objc func markUnreadAndGoToNextUnread(_ sender: Any?) {
		coordinator.markAsUnreadForCurrentArticle()
		coordinator.selectNextUnread()
	}
	
	@objc func markAllAsReadAndGoToNextUnread(_ sender: Any?) {
		coordinator.markAllAsReadInTimeline()
		coordinator.selectNextUnread()
	}
	
	@objc func markOlderArticlesAsRead(_ sender: Any?) {
		coordinator.markAsReadOlderArticlesInTimeline()
	}
	
	@objc func markUnread(_ sender: Any?) {
		coordinator.markAsUnreadForCurrentArticle()
	}
	
	@objc func goToPreviousSubscription(_ sender: Any?) {
		coordinator.selectPrevFeed()
	}
	
	@objc func goToNextSubscription(_ sender: Any?) {
		coordinator.selectNextFeed()
	}
	
	@objc func openInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentArticle()
	}
	
	@objc func addNewFeed(_ sender: Any?) {
		coordinator.showAdd(.feed)
	}

	@objc func addNewFolder(_ sender: Any?) {
		coordinator.showAdd(.folder)
	}

	@objc func refresh(_ sender: Any?) {
		AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present(self))
	}
	
	@objc func goToToday(_ sender: Any?) {
		coordinator.selectTodayFeed()
	}
	
	@objc func goToAllUnread(_ sender: Any?) {
		coordinator.selectAllUnreadFeed()
	}
	
	@objc func goToStarred(_ sender: Any?) {
		coordinator.selectStarredFeed()
	}
	
	@objc func toggleRead(_ sender: Any?) {
		coordinator.toggleReadForCurrentArticle()
	}
	
	@objc func toggleStarred(_ sender: Any?) {
		coordinator.toggleStarredForCurrentArticle()
	}
	
}
