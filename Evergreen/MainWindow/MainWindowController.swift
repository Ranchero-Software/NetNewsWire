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
    
	var isOpen: Bool {
		return isWindowLoaded && window!.isVisible
	}

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

			if let window = window {
				let point = NSPoint(x: 128, y: 64)
				let size = NSSize(width: 1000, height: 700)
				let minSize = NSSize(width: 600, height: 600)
				window.setPointAndSizeAdjustingForScreen(point: point, size: size, minimumSize: minSize)
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

	// MARK: Sidebar

	func selectedObjectsInSidebar() -> [AnyObject]? {

		return sidebarViewController?.selectedObjects
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
	
	@objc func makeToolbarValidate(_ sender: Any?) {
		
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

		if item.action == #selector(markOlderArticlesAsRead(_:)) {
			return canMarkOlderArticlesAsRead()
		}

		if item.action == #selector(toolbarShowShareMenu(_:)) {
			return canShowShareMenu()
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

	func makeTimelineViewFirstResponder() {

		guard let window = window, let timelineViewController = timelineViewController else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(timelineViewController.tableView)
	}

	@IBAction func nextUnread(_ sender: Any?) {
		
		guard let timelineViewController = timelineViewController, let sidebarViewController = sidebarViewController else {
			return
		}
		
		if timelineViewController.canGoToNextUnread() {
			goToNextUnreadInTimeline()
		}
		else if sidebarViewController.canGoToNextUnread() {
			sidebarViewController.goToNextUnread()
			if timelineViewController.canGoToNextUnread() {
				goToNextUnreadInTimeline()
			}
		}
	}

	func goToNextUnreadInTimeline() {

		guard let timelineViewController = timelineViewController else {
			return
		}

		if timelineViewController.canGoToNextUnread() {
			timelineViewController.goToNextUnread()
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

		timelineViewController?.markOlderArticlesAsRead()
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

	@IBAction func gotoToday(_ sender: Any?) {

		sidebarViewController?.gotoToday(sender)
	}

	@IBAction func gotoAllUnread(_ sender: Any?) {

		sidebarViewController?.gotoAllUnread(sender)
	}

	@IBAction func gotoStarred(_ sender: Any?) {

		sidebarViewController?.gotoStarred(sender)
	}

	@IBAction func toolbarShowShareMenu(_ sender: Any?) {

		guard let selectedArticles = selectedArticles, !selectedArticles.isEmpty else {
			assertionFailure("Expected toolbarShowShareMenu to be called only when there are selected articles.")
			return
		}
		guard let shareToolbarItem = shareToolbarItem else {
			assertionFailure("Expected toolbarShowShareMenu to be called only by the Share item in the toolbar.")
			return
		}
		guard let view = shareToolbarItem.view else {
			// TODO: handle menu form representation
			return
		}

		let items = selectedArticles.map { ArticlePasteboardWriter(article: $0) }
		let sharingServicePicker = NSSharingServicePicker(items: items)
		sharingServicePicker.delegate = self
		sharingServicePicker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
	}

	private func canShowShareMenu() -> Bool {

		guard let selectedArticles = selectedArticles else {
			return false
		}
		return !selectedArticles.isEmpty
	}
}

// MARK: - NSSharingServicePickerDelegate

extension MainWindowController: NSSharingServicePickerDelegate {

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {

		let sendToServices = appDelegate.sendToCommands.compactMap { (sendToCommand) -> NSSharingService? in

			guard let object = items.first else {
				return nil
			}
			guard sendToCommand.canSendObject(object, selectedText: nil) else {
				return nil
			}

			let image = sendToCommand.image ?? appDelegate.genericFeedImage ?? NSImage()
			return NSSharingService(title: sendToCommand.title, image: image, alternateImage: nil) {
				sendToCommand.sendObject(object, selectedText: nil)
			}
		}
		return proposedServices + sendToServices
	}
}

// MARK: - NSToolbarDelegate

extension NSToolbarItem.Identifier {
	static let Share = NSToolbarItem.Identifier("share")
}

extension MainWindowController: NSToolbarDelegate {

	func toolbarWillAddItem(_ notification: Notification) {

		// The share button should send its action on mouse down, not mouse up.

		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}
		guard item.itemIdentifier == .Share, let button = item.view as? NSButton else {
			return
		}

		button.sendAction(on: .leftMouseDown)
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

	func canMarkOlderArticlesAsRead() -> Bool {

		return timelineViewController?.canMarkOlderArticlesAsRead() ?? false
	}

	func updateWindowTitle() {

		if unreadCount < 1 {
			window?.title = appDelegate.appName!
		}
		else if unreadCount > 0 {
			window?.title = "\(appDelegate.appName!) (\(unreadCount))"
		}
	}

	// MARK: - Toolbar

	private var shareToolbarItem: NSToolbarItem? {
		return existingToolbarItem(identifier: .Share)
	}

	func existingToolbarItem(identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {

		guard let toolbarItems = window?.toolbar?.items else {
			return nil
		}
		for toolbarItem in toolbarItems {
			if toolbarItem.itemIdentifier == identifier {
				return toolbarItem
			}
		}
		return nil
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

