//
//  RootSplitViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class RootSplitViewController: UISplitViewController {
	
	var coordinator: SceneCoordinator!
	
	lazy var keyboardManager = KeyboardManager(type: .global, coordinator: coordinator)
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
	
}
