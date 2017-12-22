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

	static var didPositionWindowOnFirstRun = false

    override func windowDidLoad() {
        
        super.windowDidLoad()

		if !AppDefaults.shared.showTitleOnMainWindow {
			window?.titleVisibility = .hidden
		}

		window?.setFrameUsingName(windowAutosaveName, force: true)
		if AppDefaults.shared.isFirstRun && !MainWindowController.didPositionWindowOnFirstRun {

			if let window = window, let screen = window.screen {
				let width: CGFloat = 1280.0
				let height: CGFloat = 768.0
				let insetX: CGFloat = 192.0
				let insetY: CGFloat = 96.0

				window.setContentSize(NSSize(width: width, height: height))
				window.setFrameTopLeftPoint(NSPoint(x: insetX, y: screen.visibleFrame.maxY - insetY))

				MainWindowController.didPositionWindowOnFirstRun = true
			}
		}

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

		guard let navigationKey = note.userInfo?[UserInfoKey.navigationKeyPressed] as? Int else {
			return
		}
		guard let contentView = window?.contentView, let view = note.object as? NSView, view.isDescendant(of: contentView) else {
			return
		}

		if navigationKey == NSRightArrowFunctionKey {
			handleRightArrowFunctionKey(in: view)
		}
		if navigationKey == NSLeftArrowFunctionKey {
			handleLeftArrowFunctionKey(in: view)
		}
	}

	@objc func refreshProgressDidChange(_ note: Notification) {
		
		performSelectorCoalesced(#selector(MainWindowController.makeToolbarValidate(_:)), with: nil, delay: 0.1)
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

		if item.action == #selector(markRead(_:)) {
			return canMarkRead()
		}

		return true
	}

	// MARK: - Actions

	@IBAction func scrollOrGoToNextUnread(_ sender: Any?) {

		guard let detailViewController = detailViewController else {
			return
		}

		detailViewController.canScrollDown { (canScroll) in

			canScroll ? detailViewController.scrollPageDown(sender) : self.nextUnread(sender)
		}
	}


    @IBAction func showAddFolderWindow(_ sender: Any) {

        appDelegate.showAddFolderSheetOnWindow(window!)
    }
    
	@IBAction func openArticleInBrowser(_ sender: Any?) {
		
		if let link = currentLink {
			Browser.open(link)
		}		
	}

	@IBAction func openInBrowser(_ sender: Any?) {

		openArticleInBrowser(sender)
	}

	@IBAction func nextUnread(_ sender: Any?) {
		
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
	
	@IBAction func markAllAsRead(_ sender: Any?) {
		
		timelineViewController?.markAllAsRead()
	}

	@IBAction func markRead(_ sender: Any?) {

		timelineViewController?.markSelectedArticlesAsRead(sender)
	}

	@IBAction func markUnread(_ sender: Any?) {

		timelineViewController?.markSelectedArticlesAsUnread(sender)
	}

	@IBAction func markAllAsReadAndGoToNextUnread(_ sender: Any?) {

		markAllAsRead(sender)
		nextUnread(sender)
	}

	@IBAction func markUnreadAndGoToNextUnread(_ sender: Any?) {

		markUnread(sender)
		nextUnread(sender)
	}

	@IBAction func markReadAndGoToNextUnread(_ sender: Any?) {

		markUnread(sender)
		nextUnread(sender)
	}

	@IBAction func toggleSidebar(_ sender: Any?) {
		
		splitViewController!.toggleSidebar(sender)
	}

	@IBAction func markOlderArticlesAsRead(_ sender: Any?) {

		appDelegate.markOlderArticlesAsRead(with: window!)
	}

	@IBAction func markEverywhereAsRead(_ sender: Any?) {

		appDelegate.markEverywhereAsRead(with: window!)
	}

	@IBAction func navigateToTimeline(_ sender: Any?) {

		timelineViewController?.focus()
	}

	@IBAction func navigateToSidebar(_ sender: Any?) {

		sidebarViewController?.focus()
	}

	@IBAction func goToPreviousSubscription(_ sender: Any?) {

		sidebarViewController?.outlineView.selectPreviousRow(sender)
	}

	@IBAction func goToNextSubscription(_ sender: Any?) {

		sidebarViewController?.outlineView.selectNextRow(sender)
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

	func canMarkRead() -> Bool {

		return timelineViewController?.canMarkSelectedArticlesAsRead() ?? false
	}
	
	func updateWindowTitle() {

		if unreadCount < 1 {
			window?.title = appDelegate.appName!
		}
		else if unreadCount > 0 {
			window?.title = "\(appDelegate.appName!) (\(unreadCount))"
		}
	}

	// MARK: - Navigation

	func handleRightArrowFunctionKey(in view: NSView) {

		guard let outlineView = sidebarViewController?.outlineView, view === outlineView, let timelineViewController = timelineViewController else {
			return
		}
		timelineViewController.focus()
	}

	func handleLeftArrowFunctionKey(in view: NSView) {

		guard let timelineView = timelineViewController?.tableView, view === timelineView, let sidebarViewController = sidebarViewController else {
			return
		}
		sidebarViewController.focus()
	}
}

