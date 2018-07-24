//
//  MainWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles
import Account
import RSCore

class MainWindowController : NSWindowController, NSUserInterfaceValidations {

	@IBOutlet var toolbarDelegate: MainWindowToolbarDelegate?
	private let sharingServicePickerDelegate = MainWindowSharingServicePickerDelegate()

	private let windowAutosaveName = NSWindow.FrameAutosaveName(rawValue: "MainWindow")
	static var didPositionWindowOnFirstRun = false

	private var unreadCount: Int = 0 {
		didSet {
			if unreadCount != oldValue {
				updateWindowTitle()
			}
		}
	}

	private var shareToolbarItem: NSToolbarItem? {
		return window?.toolbar?.existingItem(withIdentifier: .Share)
	}

	private static var detailViewMinimumThickness = 384

	// MARK: - NSWindowController

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

		detailSplitViewItem?.minimumThickness = CGFloat(MainWindowController.detailViewMinimumThickness)
		restoreSplitViewState()

		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: NSApplication.willTerminateNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidBegin, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateWindowTitle()
		}
	}

	// MARK: - API

	func saveState() {

		saveSplitViewState()
	}


	func selectedObjectsInSidebar() -> [AnyObject]? {

		return sidebarViewController?.selectedObjects
	}

	// MARK: - Notifications

	@objc func applicationWillTerminate(_ note: Notification) {

		saveState()
		window?.saveFrame(usingName: windowAutosaveName)
	}

	@objc func refreshProgressDidChange(_ note: Notification) {

		CoalescingQueue.standard.add(self, #selector(makeToolbarValidate))
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	// MARK: - Toolbar
	
	@objc func makeToolbarValidate() {
		
		window?.toolbar?.validateVisibleItems()
	}

	// MARK: - NSUserInterfaceValidations
	
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

		if item.action == #selector(toggleStarred(_:)) {
			return validateToggleStarred(item)
		}

		if item.action == #selector(markOlderArticlesAsRead(_:)) {
			return canMarkOlderArticlesAsRead()
		}

		if item.action == #selector(toolbarShowShareMenu(_:)) {
			return canShowShareMenu()
		}

		if item.action == #selector(toggleSidebar(_:)) {

			guard let splitViewItem = sidebarSplitViewItem else {
				return false
			}

			let sidebarIsShowing = !splitViewItem.isCollapsed
			if let menuItem = item as? NSMenuItem {
				let title = sidebarIsShowing ? NSLocalizedString("Hide Sidebar", comment: "Menu item") : NSLocalizedString("Show Sidebar", comment: "Menu item")
				menuItem.title = title
			}

			return true
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

	@IBAction func showAddFolderWindow(_ sender: Any?) {

		appDelegate.showAddFolderSheetOnWindow(window!)
	}

	@IBAction func showAddFeedWindow(_ sender: Any?) {

		appDelegate.showAddFeedSheetOnWindow(window!, urlString: nil, name: nil)
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

	@IBAction func markAllAsRead(_ sender: Any?) {
		
		timelineViewController?.markAllAsRead()
	}

	@IBAction func markRead(_ sender: Any?) {

		timelineViewController?.markSelectedArticlesAsRead(sender)
	}

	@IBAction func markUnread(_ sender: Any?) {

		timelineViewController?.markSelectedArticlesAsUnread(sender)
	}

	@IBAction func toggleStarred(_ sender: Any?) {

		timelineViewController?.toggleStarredStatusForSelectedArticles()
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
		sharingServicePicker.delegate = sharingServicePickerDelegate
		sharingServicePicker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
	}

}

// MARK: - Scripting Access

/*
    the ScriptingMainWindowController protocol exposes a narrow set of accessors with
    internal visibility which are very similar to some private vars.
    
    These would be unnecessary if the similar accessors were marked internal rather than private,
    but for now, we'll keep the stratification of visibility
*/

extension MainWindowController : ScriptingMainWindowController {

    internal var scriptingCurrentArticle: Article? {
        return self.oneSelectedArticle
    }

    internal var scriptingSelectedArticles: [Article] {
        return self.selectedArticles ?? []
    }
}

// MARK: - Private

private extension MainWindowController {
	
	var splitViewController: NSSplitViewController? {
		guard let viewController = contentViewController else {
			return nil
		}
		return viewController.childViewControllers.first as? NSSplitViewController
	}

	var sidebarViewController: SidebarViewController? {
		return splitViewController?.splitViewItems[0].viewController as? SidebarViewController
	}
	
	var timelineViewController: TimelineViewController? {
		return splitViewController?.splitViewItems[1].viewController as? TimelineViewController
	}

	var sidebarSplitViewItem: NSSplitViewItem? {
		return splitViewController?.splitViewItems[0]
	}

	var detailSplitViewItem: NSSplitViewItem? {
		return splitViewController?.splitViewItems[2]
	}
	
	var detailViewController: DetailViewController? {
		return splitViewController?.splitViewItems[2].viewController as? DetailViewController
	}

	var selectedArticles: [Article]? {
		return timelineViewController?.selectedArticles
	}

	var oneSelectedArticle: Article? {
		if let articles = selectedArticles {
			return articles.count == 1 ? articles[0] : nil
		}
		return nil
	}

	var currentLink: String? {
		return oneSelectedArticle?.preferredLink
	}

	// MARK: - Command Validation

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

	func canShowShareMenu() -> Bool {

		guard let selectedArticles = selectedArticles else {
			return false
		}
		return !selectedArticles.isEmpty
	}

	func validateToggleStarred(_ item: NSValidatedUserInterfaceItem) -> Bool {

		let validationStatus = timelineViewController?.markStarredCommandStatus() ?? .canDoNothing
		let starring: Bool
		let result: Bool

		switch validationStatus {
		case .canMark:
			starring = true
			result = true
		case .canUnmark:
			starring = false
			result = true
		case .canDoNothing:
			starring = true
			result = false
		}

		let commandName = starring ? NSLocalizedString("Mark as Starred", comment: "Command") : NSLocalizedString("Mark as Unstarred", comment: "Command")

		if let toolbarItem = item as? NSToolbarItem {
			toolbarItem.toolTip = commandName
			if let button = toolbarItem.view as? NSButton {
				button.image = NSImage(named: starring ? .star : .unstar)
			}
		}

		if let menuItem = item as? NSMenuItem {
			menuItem.title = commandName
		}

		return result
	}

	// MARK: - Misc.

	func goToNextUnreadInTimeline() {

		guard let timelineViewController = timelineViewController else {
			return
		}

		if timelineViewController.canGoToNextUnread() {
			timelineViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
	}

	func makeTimelineViewFirstResponder() {

		guard let window = window, let timelineViewController = timelineViewController else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(timelineViewController.tableView)
	}

	func updateWindowTitle() {

		if unreadCount < 1 {
			window?.title = appDelegate.appName!
		}
		else if unreadCount > 0 {
			window?.title = "\(appDelegate.appName!) (\(unreadCount))"
		}
	}

	func saveSplitViewState() {

		// TODO: Update this for multiple windows.

		guard let splitView = splitViewController?.splitView else {
			return
		}

		let widths = splitView.arrangedSubviews.map{ Int(floor($0.frame.width)) }
		AppDefaults.shared.mainWindowWidths = widths
	}

	func restoreSplitViewState() {

		// TODO: Update this for multiple windows.

		guard let splitView = splitViewController?.splitView, let widths = AppDefaults.shared.mainWindowWidths, widths.count == 3, let window = window else {
			return
		}

		let windowWidth = Int(floor(window.frame.width))
		let dividerThickness: Int = Int(splitView.dividerThickness)
		let sidebarWidth: Int = widths[0]
		let timelineWidth: Int = widths[1]

		// Make sure the detail view has its mimimum thickness, at least.
		if windowWidth < sidebarWidth + dividerThickness + timelineWidth + dividerThickness + MainWindowController.detailViewMinimumThickness {
			return
		}

		splitView.setPosition(CGFloat(sidebarWidth), ofDividerAt: 0)
		splitView.setPosition(CGFloat(sidebarWidth + dividerThickness + timelineWidth), ofDividerAt: 1)
	}
}

