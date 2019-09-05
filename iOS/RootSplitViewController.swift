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
	
	private let keyboardManager = KeyboardManager(type: .global)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}

	// MARK: Keyboard Shortcuts
	@objc func scrollOrGoToNextUnread(_ sender: Any?) {
	}
	
	@objc func goToPreviousUnread(_ sender: Any?) {
	}
	
	@objc func nextUnread(_ sender: Any?) {
	}
	
	@objc func markRead(_ sender: Any?) {
	}
	
	@objc func markUnreadAndGoToNextUnread(_ sender: Any?) {
	}
	
	@objc func markAllAsReadAndGoToNextUnread(_ sender: Any?) {
	}
	
	@objc func markOlderArticlesAsRead(_ sender: Any?) {
	}
	
	@objc func markUnread(_ sender: Any?) {
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
	}

	@objc func addNewFolder(_ sender: Any?) {
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
	
}
