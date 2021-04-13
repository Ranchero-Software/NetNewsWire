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
	
	override var prefersStatusBarHidden: Bool {
		return coordinator.prefersStatusBarHidden
	}
	
	override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return .slide
	}
	
	override func viewDidAppear(_ animated: Bool) {
		coordinator.resetFocus()
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		self.coordinator.configurePanelMode(for: size)
		super.viewWillTransition(to: size, with: coordinator)
	}
	
	// MARK: Keyboard Shortcuts
	
	@objc func scrollOrGoToNextUnread(_ sender: Any?) {
		coordinator.scrollOrGoToNextUnread()
	}

	@objc func scrollUp(_ sender: Any?) {
		coordinator.scrollUp()
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
		coordinator.markAllAsReadInTimeline() {
			self.coordinator.selectNextUnread()
		}
	}

	@objc func markAboveAsRead(_ sender: Any?) {
		coordinator.markAboveAsRead()
	}
	
	@objc func markBelowAsRead(_ sender: Any?) {
		coordinator.markBelowAsRead()
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

	@objc func openInAppBrowser(_ sender: Any?) {
		coordinator.showInAppBrowser()
	}
	
	@objc func articleSearch(_ sender: Any?) {
		coordinator.showSearch()
	}
	
	@objc func addNewFeed(_ sender: Any?) {
		coordinator.showAddWebFeed()
	}

	@objc func addNewFolder(_ sender: Any?) {
		coordinator.showAddFolder()
	}

	@objc func cleanUp(_ sender: Any?) {
		coordinator.cleanUp(conditional: false)
	}
	
	@objc func toggleReadFeedsFilter(_ sender: Any?) {
		coordinator.toggleReadFeedsFilter()
	}
	
	@objc func toggleReadArticlesFilter(_ sender: Any?) {
		coordinator.toggleReadArticlesFilter()
	}
	
	@objc func refresh(_ sender: Any?) {
		appDelegate.manualRefresh(errorHandler: ErrorHandler.present(self))
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

	@objc func goToSettings(_ sender: Any?) {
		coordinator.showSettings()
	}

	@objc func toggleRead(_ sender: Any?) {
		coordinator.toggleReadForCurrentArticle()
	}
	
	@objc func toggleStarred(_ sender: Any?) {
		coordinator.toggleStarredForCurrentArticle()
	}

	@objc func toggleSidebar(_ sender: Any?) {
		coordinator.toggleSidebar()
	}
}
