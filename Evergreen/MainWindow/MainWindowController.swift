//
//  MainWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import Data
import Account

private let kWindowFrameKey = "MainWindow"

class MainWindowController : NSWindowController, NSUserInterfaceValidations {
    
    // MARK: NSWindowController

	private let windowAutosaveName = NSWindow.FrameAutosaveName(rawValue: kWindowFrameKey)
	private var unreadCount: Int = 0 {
		didSet {
			if unreadCount != oldValue {
				updateWindowTitle()
			}
		}
	}

    override func windowDidLoad() {
        
        super.windowDidLoad()
        
		window?.setFrameUsingName(windowAutosaveName, force: true)
		
		detailSplitViewItem?.minimumThickness = 384
		
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(appNavigationKeyPressed(_:)), name: .AppNavigationKeyPressed, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidBegin, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateWindowTitle()
		}
	}
	
    // MARK: Notifications
    
	@objc func applicationWillTerminate(_ note: Notification) {
        
		window?.saveFrame(usingName: windowAutosaveName)
    }

	@objc func appNavigationKeyPressed(_ note: Notification) {

		guard let navigationKey = note.appInfo?.navigationKey else {
			return
		}
		guard let contentView = window?.contentView, let view = note.object as? NSView, view.isDescendant(of: contentView) else {
			return
		}

		print(navigationKey)
	}

	@objc func refreshProgressDidChange(_ note: Notification) {
		
		rs_performSelectorCoalesced(#selector(MainWindowController.makeToolbarValidate(_:)), with: nil, afterDelay: 0.1)
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	// MARK: Toolbar
	
	@objc func makeToolbarValidate(_ sender: Any) {
		
		window?.toolbar?.validateVisibleItems()
	}
	
	// MARK: NSUserInterfaceValidations
	
	public func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		
		if item.action == #selector(openArticleInBrowser(_:)) {
			return currentLink != nil
		}
		
		if item.action == #selector(nextUnread(_:)) {
			return canGoToNextUnread()
		}
		
		if item.action == #selector(markAllAsRead(_:)) {
			return canMarkAllAsRead()
		}
		
		return true
	}

	// MARK: Actions
	
	@IBAction func openArticleInBrowser(_ sender: AnyObject?) {
		
		if let link = currentLink {
			Browser.open(link)
		}		
	}
	
	@IBAction func nextUnread(_ sender: AnyObject?) {
		
		guard let timelineViewController = timelineViewController, let sidebarViewController = sidebarViewController else {
			return
		}
		
		func makeTimelineViewFirstResponder() {

			window!.makeFirstResponderUnlessDescendantIsFirstResponder(timelineViewController.tableView)
		}
		
		if timelineViewController.canGoToNextUnread() {
			timelineViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
		else if sidebarViewController.canGoToNextUnread() {
			sidebarViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
	}
	
	@IBAction func markAllAsRead(_ sender: AnyObject?) {
		
		timelineViewController?.markAllAsRead()
	}
	
	@IBAction func toggleSidebar(_ sender: AnyObject?) {
		
		splitViewController!.toggleSidebar(sender)
	}
}

// MARK: - Private

private extension MainWindowController {
	
	var splitViewController: NSSplitViewController? {
		get {
			guard let viewController = contentViewController else {
				return nil
			}
			return viewController.childViewControllers.first as? NSSplitViewController
		}
	}

	var sidebarViewController: SidebarViewController? {
		get {
			return splitViewController?.splitViewItems[0].viewController as? SidebarViewController
		}
	}
	
	var timelineViewController: TimelineViewController? {
		get {
			return splitViewController?.splitViewItems[1].viewController as? TimelineViewController
		}
	}
	
	var detailSplitViewItem: NSSplitViewItem? {
		get {
			return splitViewController?.splitViewItems[2]
		}
	}
	
	var detailViewController: DetailViewController? {
		get {
			return splitViewController?.splitViewItems[2].viewController as? DetailViewController
		}
	}

	var selectedArticles: [Article]? {
		get {
			return timelineViewController?.selectedArticles
		}
	}
	
	var oneSelectedArticle: Article? {
		get {
			if let articles = selectedArticles {
				return articles.count == 1 ? articles[0] : nil
			}
			return nil
		}
	}
	
	var currentLink: String? {
		get {
			return oneSelectedArticle?.preferredLink
		}
	}
	
	func canGoToNextUnread() -> Bool {
		
		guard let timelineViewController = timelineViewController, let sidebarViewController = sidebarViewController else {
			return false
		}

		return timelineViewController.canGoToNextUnread() || sidebarViewController.canGoToNextUnread()
	}
	
	func canMarkAllAsRead() -> Bool {
		
		return timelineViewController?.canMarkAllAsRead() ?? false
	}

	func updateWindowTitle() {

		if unreadCount < 1 {
			window?.title = appName
		}
		else if unreadCount > 0 {
			window?.title = "\(appName) (\(unreadCount))"
		}
	}
}

