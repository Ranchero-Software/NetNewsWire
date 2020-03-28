//
//  MainWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import UserNotifications
import Articles
import Account
import RSCore

enum TimelineSourceMode {
	case regular, search
}

class MainWindowController : NSWindowController, NSUserInterfaceValidations {

	private var activityManager = ActivityManager()

	private var isShowingExtractedArticle = false
	private var articleExtractor: ArticleExtractor? = nil
	private var sharingServicePickerDelegate: NSSharingServicePickerDelegate?

	private let windowAutosaveName = NSWindow.FrameAutosaveName("MainWindow")
	private static let mainWindowWidthsStateKey = "mainWindowWidthsStateKey"

	private var currentFeedOrFolder: AnyObject? {
		// Nil for none or multiple selection.
		guard let selectedObjects = selectedObjectsInSidebar(), selectedObjects.count == 1 else {
			return nil
		}
		return selectedObjects.first
	}
	
	private var shareToolbarItem: NSToolbarItem? {
		return window?.toolbar?.existingItem(withIdentifier: .Share)
	}

	private static var detailViewMinimumThickness = 384
	private var sidebarViewController: SidebarViewController?
	private var timelineContainerViewController: TimelineContainerViewController?
	private var detailViewController: DetailViewController?
	private var currentSearchField: NSSearchField? = nil
	private var searchString: String? = nil
	private var lastSentSearchString: String? = nil
	private var timelineSourceMode: TimelineSourceMode = .regular {
		didSet {
			timelineContainerViewController?.showTimeline(for: timelineSourceMode)
			detailViewController?.showDetail(for: timelineSourceMode)
		}
	}
	private var searchSmartFeed: SmartFeed? = nil

	// MARK: - NSWindowController

	override func windowDidLoad() {
		super.windowDidLoad()

		sharingServicePickerDelegate = SharingServicePickerDelegate(self.window)
		
		if !AppDefaults.showTitleOnMainWindow {
			window?.titleVisibility = .hidden
		}
		
		if let window = window {
			let point = NSPoint(x: 128, y: 64)
			let size = NSSize(width: 1000, height: 700)
			let minSize = NSSize(width: 600, height: 600)
			window.setPointAndSizeAdjustingForScreen(point: point, size: size, minimumSize: minSize)
		}

		detailSplitViewItem?.minimumThickness = CGFloat(MainWindowController.detailViewMinimumThickness)

		sidebarViewController = splitViewController?.splitViewItems[0].viewController as? SidebarViewController
		sidebarViewController!.delegate = self

		timelineContainerViewController = splitViewController?.splitViewItems[1].viewController as? TimelineContainerViewController
		timelineContainerViewController!.delegate = self

		detailViewController = splitViewController?.splitViewItems[2].viewController as? DetailViewController

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidBegin, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateWindowTitle()
		}
	}

	// MARK: - API

	func selectedObjectsInSidebar() -> [AnyObject]? {
		return sidebarViewController?.selectedObjects
	}

	func handle(_ response: UNNotificationResponse) {
		let userInfo = response.notification.request.content.userInfo
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any] else { return }
		sidebarViewController?.deepLinkRevealAndSelect(for: articlePathUserInfo)
		currentTimelineViewController?.goToDeepLink(for: articlePathUserInfo)
	}

	func handle(_ activity: NSUserActivity) {
		guard let userInfo = activity.userInfo else { return }
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any] else { return }
		sidebarViewController?.deepLinkRevealAndSelect(for: articlePathUserInfo)
		currentTimelineViewController?.goToDeepLink(for: articlePathUserInfo)
	}

	func saveStateToUserDefaults() {
		AppDefaults.windowState = savableState()
		window?.saveFrame(usingName: windowAutosaveName)
	}
	
	func restoreStateFromUserDefaults() {
		if let state = AppDefaults.windowState {
			restoreState(from: state)
			window?.setFrameUsingName(windowAutosaveName, force: true)
		}
	}
	
	// MARK: - Notifications

	@objc func refreshProgressDidChange(_ note: Notification) {
		CoalescingQueue.standard.add(self, #selector(makeToolbarValidate))
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		updateWindowTitleIfNecessary(note.object)
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		updateWindowTitleIfNecessary(note.object)
	}

	private func updateWindowTitleIfNecessary(_ noteObject: Any?) {
		
		if let folder = currentFeedOrFolder as? Folder, let noteObject = noteObject as? Folder {
			if folder == noteObject {
				updateWindowTitle()
				return
			}
		}
		
		if let feed = currentFeedOrFolder as? WebFeed, let noteObject = noteObject as? WebFeed {
			if feed == noteObject {
				updateWindowTitle()
				return
			}
		}
		
		// If we don't recognize the changed object, we will test it for identity instead
		// of equality.  This works well for us if the window title is displaying a
		// PsuedoFeed object.
		if let currentObject = currentFeedOrFolder, let noteObject = noteObject {
			if currentObject === noteObject as AnyObject {
				updateWindowTitle()
			}
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

		if item.action == #selector(toggleRead(_:)) {
			return validateToggleRead(item)
		}

		if item.action == #selector(toggleStarred(_:)) {
			return validateToggleStarred(item)
		}

		if item.action == #selector(markAboveArticlesAsRead(_:)) {
			return canMarkAboveArticlesAsRead()
		}

		if item.action == #selector(markBelowArticlesAsRead(_:)) {
			return canMarkBelowArticlesAsRead()
		}

		if item.action == #selector(toggleArticleExtractor(_:)) {
			return validateToggleArticleExtractor(item)
		}
		
		if item.action == #selector(toolbarShowShareMenu(_:)) {
			return canShowShareMenu()
		}

		if item.action == #selector(moveFocusToSearchField(_:)) {
			return currentSearchField != nil
		}

		if item.action == #selector(cleanUp(_:)) {
			return validateCleanUp(item)
		}

		if item.action == #selector(toggleReadFeedsFilter(_:)) {
			return validateToggleReadFeeds(item)
		}

		if item.action == #selector(toggleReadArticlesFilter(_:)) {
			return validateToggleReadArticles(item)
		}

		if item.action == #selector(toggleTheSidebar(_:)) {
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
			NSCursor.setHiddenUntilMouseMoves(true)
			canScroll ? detailViewController.scrollPageDown(sender) : self.nextUnread(sender)
		}
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
		guard let timelineViewController = currentTimelineViewController, let sidebarViewController = sidebarViewController else {
			return
		}

		NSCursor.setHiddenUntilMouseMoves(true)

		// TODO: handle search mode
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
		currentTimelineViewController?.markAllAsRead()
	}

	@IBAction func toggleRead(_ sender: Any?) {
		currentTimelineViewController?.toggleReadStatusForSelectedArticles()
	}

	@IBAction func markRead(_ sender: Any?) {
		currentTimelineViewController?.markSelectedArticlesAsRead(sender)
	}

	@IBAction func markUnread(_ sender: Any?) {
		currentTimelineViewController?.markSelectedArticlesAsUnread(sender)
	}

	@IBAction func toggleStarred(_ sender: Any?) {
		currentTimelineViewController?.toggleStarredStatusForSelectedArticles()
	}

	@IBAction func toggleArticleExtractor(_ sender: Any?) {
		
		guard let currentLink = currentLink, let article = oneSelectedArticle else {
			return
		}

		defer {
			makeToolbarValidate()
		}
		
		if articleExtractor?.state == .failedToParse {
			startArticleExtractorForCurrentLink()
			return
		}
		
		guard articleExtractor?.state != .processing else {
			articleExtractor?.cancel()
			articleExtractor = nil
			isShowingExtractedArticle = false
			detailViewController?.setState(DetailState.article(article), mode: timelineSourceMode)
			return
		}
		
		guard !isShowingExtractedArticle else {
			isShowingExtractedArticle = false
			detailViewController?.setState(DetailState.article(article), mode: timelineSourceMode)
			return
		}
		
		if let articleExtractor = articleExtractor, let extractedArticle = articleExtractor.article {
			if currentLink == articleExtractor.articleLink {
				isShowingExtractedArticle = true
				let detailState = DetailState.extracted(article, extractedArticle)
				detailViewController?.setState(detailState, mode: timelineSourceMode)
			}
		} else {
			startArticleExtractorForCurrentLink()
		}
		
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

	@IBAction func toggleTheSidebar(_ sender: Any?) {
		splitViewController!.toggleSidebar(sender)
		guard let splitViewItem = sidebarSplitViewItem else { return }
		if splitViewItem.isCollapsed {
			currentTimelineViewController?.focus()
		} else {
			sidebarViewController?.focus()
		}
	}

	@IBAction func markAboveArticlesAsRead(_ sender: Any?) {
		currentTimelineViewController?.markAboveArticlesRead()
	}

	@IBAction func markBelowArticlesAsRead(_ sender: Any?) {
		currentTimelineViewController?.markBelowArticlesRead()
	}

	@IBAction func navigateToTimeline(_ sender: Any?) {
		currentTimelineViewController?.focus()
	}

	@IBAction func navigateToSidebar(_ sender: Any?) {
		sidebarViewController?.focus()
	}

	@IBAction func navigateToDetail(_ sender: Any?) {
		detailViewController?.focus()
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

		let sortedArticles = selectedArticles.sortedByDate(.orderedAscending)
		let items = sortedArticles.map { ArticlePasteboardWriter(article: $0) }
		let sharingServicePicker = NSSharingServicePicker(items: items)
		sharingServicePicker.delegate = sharingServicePickerDelegate
		sharingServicePicker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
	}

	@IBAction func moveFocusToSearchField(_ sender: Any?) {
		guard let searchField = currentSearchField else {
			return
		}
		window?.makeFirstResponder(searchField)
	}

	@IBAction func cleanUp(_ sender: Any?) {
		timelineContainerViewController?.cleanUp()
	}
	
	@IBAction func toggleReadFeedsFilter(_ sender: Any?) {
		sidebarViewController?.toggleReadFilter()
	}
	
	@IBAction func toggleReadArticlesFilter(_ sender: Any?) {
		timelineContainerViewController?.toggleReadFilter()
	}
	
}

// MARK: NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
	
	func window(_ window: NSWindow, willEncodeRestorableState coder: NSCoder) {
		coder.encode(savableState(), forKey: UserInfoKey.windowState)
	}

	func window(_ window: NSWindow, didDecodeRestorableState coder: NSCoder) {
		guard let state = try? coder.decodeTopLevelObject(forKey: UserInfoKey.windowState) as? [AnyHashable : Any] else { return }
		restoreState(from: state)
	}

	func windowWillClose(_ notification: Notification) {
		detailViewController?.stopMediaPlayback()
		appDelegate.removeMainWindow(self)
	}
	
}

// MARK: - SidebarDelegate

extension MainWindowController: SidebarDelegate {

	func sidebarSelectionDidChange(_: SidebarViewController, selectedObjects: [AnyObject]?) {
		// Don’t update the timeline if it already has those objects.
		let representedObjectsAreTheSame = timelineContainerViewController?.regularTimelineViewControllerHasRepresentedObjects(selectedObjects) ?? false
		if !representedObjectsAreTheSame {
			timelineContainerViewController?.setRepresentedObjects(selectedObjects, mode: .regular)
			forceSearchToEnd()
		}
		updateWindowTitle()
		NotificationCenter.default.post(name: .InspectableObjectsDidChange, object: nil)
	}

	func unreadCount(for representedObject: AnyObject) -> Int {
		guard let timelineViewController = regularTimelineViewController else {
			return 0
		}
		guard timelineViewController.representsThisObjectOnly(representedObject) else {
			return 0
		}
		return timelineViewController.unreadCount
	}
	
	func sidebarInvalidatedRestorationState(_: SidebarViewController) {
		invalidateRestorableState()
	}
	
}

// MARK: - TimelineContainerViewControllerDelegate

extension MainWindowController: TimelineContainerViewControllerDelegate {

	func timelineSelectionDidChange(_: TimelineContainerViewController, articles: [Article]?, mode: TimelineSourceMode) {
		activityManager.invalidateReading()
		
		articleExtractor?.cancel()
		articleExtractor = nil
		isShowingExtractedArticle = false
		makeToolbarValidate()
		
		let detailState: DetailState
		if let articles = articles {
			if articles.count == 1 {
				activityManager.reading(feed: nil, article: articles.first)
				if articles.first?.webFeed?.isArticleExtractorAlwaysOn ?? false {
					detailState = .loading
					startArticleExtractorForCurrentLink()
				} else {
					detailState = .article(articles.first!)
				}
			} else {
				detailState = .multipleSelection
			}
		} else {
			detailState = .noSelection
		}

		detailViewController?.setState(detailState, mode: mode)
	}

	func timelineRequestedWebFeedSelection(_: TimelineContainerViewController, webFeed: WebFeed) {
		sidebarViewController?.selectFeed(webFeed)
	}
	
	func timelineInvalidatedRestorationState(_: TimelineContainerViewController) {
		invalidateRestorableState()
	}
	
}

// MARK: - NSSearchFieldDelegate

extension MainWindowController: NSSearchFieldDelegate {

	func searchFieldDidStartSearching(_ sender: NSSearchField) {
		startSearchingIfNeeded()
	}

	func searchFieldDidEndSearching(_ sender: NSSearchField) {
		stopSearchingIfNeeded()
	}

	@IBAction func runSearch(_ sender: NSSearchField) {
		if sender.stringValue == "" {
			return
		}
		startSearchingIfNeeded()
		handleSearchFieldTextChange(sender)
	}

	private func handleSearchFieldTextChange(_ searchField: NSSearchField) {
		let s = searchField.stringValue
		if s == searchString {
			return
		}
		searchString = s
		updateSmartFeed()
	}

	func updateSmartFeed() {
		guard timelineSourceMode == .search, let searchString = searchString else {
			return
		}
		if searchString == lastSentSearchString {
			return
		}
		lastSentSearchString = searchString
		let smartFeed = SmartFeed(delegate: SearchFeedDelegate(searchString: searchString))
		timelineContainerViewController?.setRepresentedObjects([smartFeed], mode: .search)
		searchSmartFeed = smartFeed
	}

	func forceSearchToEnd() {
		timelineSourceMode = .regular
		searchString = nil
		lastSentSearchString = nil
		if let searchField = currentSearchField {
			searchField.stringValue = ""
		}
	}

	private func startSearchingIfNeeded() {
		timelineSourceMode = .search
	}

	private func stopSearchingIfNeeded() {
		searchString = nil
		lastSentSearchString = nil
		timelineSourceMode = .regular
		timelineContainerViewController?.setRepresentedObjects(nil, mode: .search)
	}
}

// MARK: - ArticleExtractorDelegate

extension MainWindowController: ArticleExtractorDelegate {
	
	func articleExtractionDidFail(with: Error) {
		makeToolbarValidate()
	}
	
	func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
		if let article = oneSelectedArticle, articleExtractor?.state != .cancelled {
			isShowingExtractedArticle = true
			let detailState = DetailState.extracted(article, extractedArticle)
			detailViewController?.setState(detailState, mode: timelineSourceMode)
			makeToolbarValidate()
		}
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

// MARK: - NSToolbarDelegate

extension NSToolbarItem.Identifier {
	static let Share = NSToolbarItem.Identifier("share")
	static let Search = NSToolbarItem.Identifier("search")
}

extension MainWindowController: NSToolbarDelegate {

	func toolbarWillAddItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if item.itemIdentifier == .Share, let button = item.view as? NSButton {
			// The share button should send its action on mouse down, not mouse up.
			button.sendAction(on: .leftMouseDown)
		}

		if item.itemIdentifier == .Search, let searchField = item.view as? NSSearchField {
			searchField.delegate = self
			searchField.target = self
			searchField.action = #selector(runSearch(_:))
			currentSearchField = searchField
		}
	}

	func toolbarDidRemoveItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if item.itemIdentifier == .Search, let searchField = item.view as? NSSearchField {
			searchField.delegate = nil
			searchField.target = nil
			searchField.action = nil
			currentSearchField = nil
		}
	}
}

// MARK: - Private

private extension MainWindowController {

	var splitViewController: NSSplitViewController? {
		guard let viewController = contentViewController else {
			return nil
		}
		return viewController.children.first as? NSSplitViewController
	}

	var currentTimelineViewController: TimelineViewController? {
		return timelineContainerViewController?.currentTimelineViewController
	}

	var regularTimelineViewController: TimelineViewController? {
		return timelineContainerViewController?.regularTimelineViewController
	}

	var sidebarSplitViewItem: NSSplitViewItem? {
		return splitViewController?.splitViewItems[0]
	}

	var detailSplitViewItem: NSSplitViewItem? {
		return splitViewController?.splitViewItems[2]
	}
	
	var selectedArticles: [Article]? {
		return currentTimelineViewController?.selectedArticles
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

	// MARK: - State Restoration
	
	func savableState() -> [AnyHashable : Any] {
		var state = [AnyHashable : Any]()
		saveSplitViewState(to: &state)
		sidebarViewController?.saveState(to: &state)
		timelineContainerViewController?.saveState(to: &state)
		return state
	}

	func restoreState(from state: [AnyHashable : Any]) {
		restoreSplitViewState(from: state)
		sidebarViewController?.restoreState(from: state)
		timelineContainerViewController?.restoreState(from: state)
	}

	// MARK: - Command Validation

	func canGoToNextUnread() -> Bool {
		
		guard let timelineViewController = currentTimelineViewController, let sidebarViewController = sidebarViewController else {
			return false
		}
		// TODO: handle search mode
		return timelineViewController.canGoToNextUnread() || sidebarViewController.canGoToNextUnread()
	}
	
	func canMarkAllAsRead() -> Bool {
		
		return currentTimelineViewController?.canMarkAllAsRead() ?? false
	}
	
	func validateToggleRead(_ item: NSValidatedUserInterfaceItem) -> Bool {

		let validationStatus = currentTimelineViewController?.markReadCommandStatus() ?? .canDoNothing
		let markingRead: Bool
		let result: Bool
		
		switch validationStatus {
		case .canMark:
			markingRead = true
			result = true
		case .canUnmark:
			markingRead = false
			result = true
		case .canDoNothing:
			markingRead = true
			result = false
		}
		
		let commandName = markingRead ? NSLocalizedString("Mark as Read", comment: "Command") : NSLocalizedString("Mark as Unread", comment: "Command")
		
		if let toolbarItem = item as? NSToolbarItem {
			toolbarItem.toolTip = commandName
		}
		
		if let menuItem = item as? NSMenuItem {
			menuItem.title = commandName
		}
		
		return result
	}

	func validateToggleArticleExtractor(_ item: NSValidatedUserInterfaceItem) -> Bool {
		guard !AppDefaults.isDeveloperBuild else {
			return false
		}
		
		guard let toolbarItem = item as? NSToolbarItem, let toolbarButton = toolbarItem.view as? ArticleExtractorButton else {
			if let menuItem = item as? NSMenuItem {
				menuItem.state = isShowingExtractedArticle ? .on : .off
			}
			return currentLink != nil
		}
		
		toolbarButton.state = isShowingExtractedArticle ? .on : .off

		guard let state = articleExtractor?.state else {
			toolbarButton.isError = false
			toolbarButton.isInProgress = false
			toolbarButton.state = .off
			return currentLink != nil
		}
		
		switch state {
		case .processing:
			toolbarButton.isError = false
			toolbarButton.isInProgress = true
		case .failedToParse:
			toolbarButton.isError = true
			toolbarButton.isInProgress = false
		case .ready, .cancelled, .complete:
			toolbarButton.isError = false
			toolbarButton.isInProgress = false
		}

		return true
	}

	func canMarkAboveArticlesAsRead() -> Bool {
		return currentTimelineViewController?.canMarkAboveArticlesAsRead() ?? false
	}

	func canMarkBelowArticlesAsRead() -> Bool {
		return currentTimelineViewController?.canMarkBelowArticlesAsRead() ?? false
	}
	
	func canShowShareMenu() -> Bool {

		guard let selectedArticles = selectedArticles else {
			return false
		}
		return !selectedArticles.isEmpty
	}

	func validateToggleStarred(_ item: NSValidatedUserInterfaceItem) -> Bool {

		let validationStatus = currentTimelineViewController?.markStarredCommandStatus() ?? .canDoNothing
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
//			if let button = toolbarItem.view as? NSButton {
//				button.image = NSImage(named: starring ? .star : .unstar)
//			}
		}

		if let menuItem = item as? NSMenuItem {
			menuItem.title = commandName
		}

		return result
	}
	
	func validateCleanUp(_ item: NSValidatedUserInterfaceItem) -> Bool {
		let isSidebarFiltered = sidebarViewController?.isReadFiltered ?? false
		let isTimelineFiltered = timelineContainerViewController?.isReadFiltered ?? false
		return isSidebarFiltered || isTimelineFiltered
	}

	func validateToggleReadFeeds(_ item: NSValidatedUserInterfaceItem) -> Bool {
		guard let menuItem = item as? NSMenuItem else { return false }

		let showCommand = NSLocalizedString("Show Read Feeds", comment: "Command")
		let hideCommand = NSLocalizedString("Hide Read Feeds", comment: "Command")
		menuItem.title = sidebarViewController?.isReadFiltered ?? false ? showCommand : hideCommand
		return true
	}

	func validateToggleReadArticles(_ item: NSValidatedUserInterfaceItem) -> Bool {
		guard let menuItem = item as? NSMenuItem else { return false }
		
		let showCommand = NSLocalizedString("Show Read Articles", comment: "Command")
		let hideCommand = NSLocalizedString("Hide Read Articles", comment: "Command")

		if let isReadFiltered = timelineContainerViewController?.isReadFiltered {
			menuItem.title = isReadFiltered ? showCommand : hideCommand
			return true
		} else {
			menuItem.title = showCommand
			return false
		}
	}

	// MARK: - Misc.

	func goToNextUnreadInTimeline() {

		guard let timelineViewController = currentTimelineViewController else {
			return
		}

		if timelineViewController.canGoToNextUnread() {
			timelineViewController.goToNextUnread()
			makeTimelineViewFirstResponder()
		}
	}

	func makeTimelineViewFirstResponder() {

		guard let window = window, let timelineViewController = currentTimelineViewController else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(timelineViewController.tableView)
	}

	func updateWindowTitle() {

		var displayName: String? = nil
		var unreadCount: Int? = nil
		
		if let displayNameProvider = currentFeedOrFolder as? DisplayNameProvider {
			displayName = displayNameProvider.nameForDisplay
		}
		
		if let unreadCountProvider = currentFeedOrFolder as? UnreadCountProvider {
			unreadCount = unreadCountProvider.unreadCount
		}
		
		if displayName != nil {
			if unreadCount ?? 0 > 0 {
				window?.title = "\(displayName!) (\(unreadCount!))"
			}
			else {
				window?.title = "\(displayName!)"
			}
		}
		else {
			window?.title = appDelegate.appName!
			return
		}
		
	}
	
	func startArticleExtractorForCurrentLink() {
		if let link = currentLink, let extractor = ArticleExtractor(link) {
			extractor.delegate = self
			extractor.process()
			articleExtractor = extractor
		}
	}

	func saveSplitViewState(to state: inout [AnyHashable : Any]) {
		guard let splitView = splitViewController?.splitView else {
			return
		}

		let widths = splitView.arrangedSubviews.map{ Int(floor($0.frame.width)) }
		state[MainWindowController.mainWindowWidthsStateKey] = widths
	}

	func restoreSplitViewState(from state: [AnyHashable : Any]) {
		guard let splitView = splitViewController?.splitView,
			let widths = state[MainWindowController.mainWindowWidthsStateKey] as? [Int],
			widths.count == 3,
			let window = window else {
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

