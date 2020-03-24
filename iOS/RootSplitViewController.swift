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
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		self.coordinator.configurePanelMode(for: size)
		super.viewWillTransition(to: size, with: coordinator)
	}
	
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
	
	@objc func articleSearch(_ sender: Any?) {
		coordinator.showSearch()
	}
	
	@objc func addNewFeed(_ sender: Any?) {
		coordinator.showAdd(.feed)
	}

	@objc func addNewFolder(_ sender: Any?) {
		coordinator.showAdd(.folder)
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
	
	@objc func toggleRead(_ sender: Any?) {
		coordinator.toggleReadForCurrentArticle()
	}
	
	@objc func toggleStarred(_ sender: Any?) {
		coordinator.toggleStarredForCurrentArticle()
	}
	
}
