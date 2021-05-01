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
		return window?.toolbar?.existingItem(withIdentifier: .share)
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
		
		if #available(macOS 11.0, *) {
			let toolbar = NSToolbar(identifier: "MainWindowToolbar")
			toolbar.allowsUserCustomization = true
			toolbar.autosavesConfiguration = true
			toolbar.displayMode = .iconOnly
			toolbar.delegate = self
			self.window?.toolbar = toolbar
		} else {
			if !AppDefaults.shared.showTitleOnMainWindow {
				window?.titleVisibility = .hidden
			}
		}
		
		if let window = window {
			let point = NSPoint(x: 128, y: 64)
			let size = NSSize(width: 1345, height: 900)
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
		AppDefaults.shared.windowState = savableState()
		window?.saveFrame(usingName: windowAutosaveName)
	}
	
	func restoreStateFromUserDefaults() {
		if let state = AppDefaults.shared.windowState {
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
		
		if item.action == #selector(copyArticleURL(_:)) {
			return canCopyArticleURL()
		}
		
		if item.action == #selector(copyExternalURL(_:)) {
			return canCopyExternalURL()
		}
		
		if item.action == #selector(openArticleInBrowser(_:)) {
			if let item = item as? NSMenuItem, item.keyEquivalentModifierMask.contains(.shift) {
				item.title = Browser.titleForOpenInBrowserInverted
			}

			return currentLink != nil
		}
		
		if item.action == #selector(nextUnread(_:)) {
			return canGoToNextUnread(wrappingToTop: true)
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

	@IBAction func scrollUp(_ sender: Any?) {
		guard let detailViewController = detailViewController else {
			return
		}
		detailViewController.canScrollUp { (canScroll) in
			if (canScroll) {
				NSCursor.setHiddenUntilMouseMoves(true)
				detailViewController.scrollPageUp(sender)
			}
		}

	}

	@IBAction func copyArticleURL(_ sender: Any?) {
		if let link = currentLink {
			URLPasteboardWriter.write(urlString: link, to: .general)
		}
	}

	@IBAction func copyExternalURL(_ sender: Any?) {
		if let link = oneSelectedArticle?.externalURL {
			URLPasteboardWriter.write(urlString: link, to: .general)
		}
	}

	@IBAction func openArticleInBrowser(_ sender: Any?) {
		if let link = currentLink {
			Browser.open(link, invertPreference: NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
		}		
	}

	@IBAction func openInBrowser(_ sender: Any?) {
		if AppDefaults.shared.openInBrowserInBackground {
			window?.makeKeyAndOrderFront(self)
		}
		openArticleInBrowser(sender)
	}

	@objc func openInAppBrowser(_ sender: Any?) {
		// There is no In-App Browser for mac - so we use safari
		openArticleInBrowser(sender)
	}

	@IBAction func openInBrowserUsingOppositeOfSettings(_ sender: Any?) {
		if !AppDefaults.shared.openInBrowserInBackground {
			window?.makeKeyAndOrderFront(self)
		}
		if let link = currentLink {
			Browser.open(link, inBackground: !AppDefaults.shared.openInBrowserInBackground)
		}
	}

	@IBAction func nextUnread(_ sender: Any?) {
		guard let timelineViewController = currentTimelineViewController, let sidebarViewController = sidebarViewController else {
			return
		}

		NSCursor.setHiddenUntilMouseMoves(true)

		// TODO: handle search mode
		if timelineViewController.canGoToNextUnread(wrappingToTop: false) {
			goToNextUnreadInTimeline(wrappingToTop: false)
		}
		else if sidebarViewController.canGoToNextUnread(wrappingToTop: true) {
			sidebarViewController.goToNextUnread(wrappingToTop: true)

			// If we ended up on the same timelineViewController, we may need to wrap
			// around to the top of its contents.
			if timelineViewController.canGoToNextUnread(wrappingToTop: true) {
				goToNextUnreadInTimeline(wrappingToTop: true)
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
		currentTimelineViewController?.markAllAsRead() {
			self.nextUnread(sender)
		}
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
	
	@IBAction func markOlderArticlesAsRead(_ sender: Any?) {
		currentTimelineViewController?.markOlderArticlesRead()
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
		updateWindowTitle()
	}

	func forceSearchToEnd() {
		timelineSourceMode = .regular
		searchString = nil
		lastSentSearchString = nil
		if let searchField = currentSearchField {
			searchField.stringValue = ""
		}
		updateWindowTitle()
	}

	private func startSearchingIfNeeded() {
		timelineSourceMode = .search
		updateWindowTitle()
	}

	private func stopSearchingIfNeeded() {
		searchString = nil
		lastSentSearchString = nil
		timelineSourceMode = .regular
		timelineContainerViewController?.setRepresentedObjects(nil, mode: .search)
		updateWindowTitle()
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
	static let sidebarToggle = NSToolbarItem.Identifier("sidebarToggle")
	static let newFeed = NSToolbarItem.Identifier("newFeed")
	static let newFolder = NSToolbarItem.Identifier("newFolder")
	static let refresh = NSToolbarItem.Identifier("refresh")
	static let newSidebarItemMenu = NSToolbarItem.Identifier("newSidebarItemMenu")
	static let timelineTrackingSeparator = NSToolbarItem.Identifier("timelineTrackingSeparator")
	static let search = NSToolbarItem.Identifier("search")
	static let markAllAsRead = NSToolbarItem.Identifier("markAllAsRead")
	static let toggleReadArticlesFilter = NSToolbarItem.Identifier("toggleReadArticlesFilter")
	static let nextUnread = NSToolbarItem.Identifier("nextUnread")
	static let markRead = NSToolbarItem.Identifier("markRead")
	static let markStar = NSToolbarItem.Identifier("markStar")
	static let readerView = NSToolbarItem.Identifier("readerView")
	static let openInBrowser = NSToolbarItem.Identifier("openInBrowser")
	static let share = NSToolbarItem.Identifier("share")
	static let cleanUp = NSToolbarItem.Identifier("cleanUp")
}

extension MainWindowController: NSToolbarDelegate {

	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		if #available(macOS 11.0, *) {

			switch itemIdentifier {

			case .sidebarToggle:
				let title = NSLocalizedString("Toggle Sidebar", comment: "Toggle Sidebar")
				return buildToolbarButton(.toggleSidebar, title, AppAssets.sidebarToggleImage, "toggleTheSidebar:")

			case .refresh:
				let title = NSLocalizedString("Refresh", comment: "Refresh")
				return buildToolbarButton(.refresh, title, AppAssets.refreshImage, "refreshAll:")
			
			case .newSidebarItemMenu:
				let toolbarItem = NSMenuToolbarItem(itemIdentifier: .newSidebarItemMenu)
				toolbarItem.image = AppAssets.addNewSidebarItemImage
				let description = NSLocalizedString("Add Item", comment: "Add Item")
				toolbarItem.toolTip = description
				toolbarItem.label = description
				toolbarItem.menu = buildNewSidebarItemMenu()
				return toolbarItem

			case .markAllAsRead:
				let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
				return buildToolbarButton(.markAllAsRead, title, AppAssets.markAllAsReadImage, "markAllAsRead:")
			
			case .toggleReadArticlesFilter:
				let title = NSLocalizedString("Read Articles Filter", comment: "Read Articles Filter")
				return buildToolbarButton(.toggleReadArticlesFilter, title, AppAssets.filterInactive, "toggleReadArticlesFilter:")
			
			case .timelineTrackingSeparator:
				return NSTrackingSeparatorToolbarItem(identifier: .timelineTrackingSeparator, splitView: splitViewController!.splitView, dividerIndex: 1)

			case .markRead:
				let title = NSLocalizedString("Mark Read", comment: "Mark Read")
				return buildToolbarButton(.markRead, title, AppAssets.readClosedImage, "toggleRead:")
			
			case .markStar:
				let title = NSLocalizedString("Star", comment: "Star")
				return buildToolbarButton(.markStar, title, AppAssets.starOpenImage, "toggleStarred:")
			
			case .nextUnread:
				let title = NSLocalizedString("Next Unread", comment: "Next Unread")
				return buildToolbarButton(.nextUnread, title, AppAssets.nextUnreadImage, "nextUnread:")
			
			case .readerView:
				let toolbarItem = RSToolbarItem(itemIdentifier: .readerView)
				toolbarItem.autovalidates = true
				let description = NSLocalizedString("Reader View", comment: "Reader View")
				toolbarItem.toolTip = description
				toolbarItem.label = description
				let button = ArticleExtractorButton()
				button.action = #selector(toggleArticleExtractor(_:))
				toolbarItem.view = button
				return toolbarItem

			case .share:
				let title = NSLocalizedString("Share", comment: "Share")
				return buildToolbarButton(.share, title, AppAssets.shareImage, "toolbarShowShareMenu:")
			
			case .openInBrowser:
				let title = NSLocalizedString("Open in Browser", comment: "Open in Browser")
				return buildToolbarButton(.openInBrowser, title, AppAssets.openInBrowserImage, "openArticleInBrowser:")
			
			case .search:
				let toolbarItem = NSSearchToolbarItem(itemIdentifier: .search)
				let description = NSLocalizedString("Search", comment: "Search")
				toolbarItem.toolTip = description
				toolbarItem.label = description
				return toolbarItem

			case .cleanUp:
				let title = NSLocalizedString("Clean Up", comment: "Clean Up")
				return buildToolbarButton(.cleanUp, title, AppAssets.cleanUpImage, "cleanUp:")
			
			default:
				break
			}

		}
		
		return nil
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		if #available(macOS 11.0, *) {
			return [
				.sidebarToggle,
				.refresh,
				.newSidebarItemMenu,
				.sidebarTrackingSeparator,
				.markAllAsRead,
				.toggleReadArticlesFilter,
				.timelineTrackingSeparator,
				.flexibleSpace,
				.nextUnread,
				.markRead,
				.markStar,
				.readerView,
				.openInBrowser,
				.share,
				.search,
				.cleanUp
			]
		} else {
			return [
				.newFeed,
				.newFolder,
				.refresh,
				.flexibleSpace,
				.markAllAsRead,
				.search,
				.flexibleSpace,
				.nextUnread,
				.markStar,
				.markRead,
				.readerView,
				.openInBrowser,
				.share,
				.cleanUp
			]
		}
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		if #available(macOS 11.0, *) {
			return [
				.flexibleSpace,
				.refresh,
				.newSidebarItemMenu,
				.sidebarTrackingSeparator,
				.markAllAsRead,
				.toggleReadArticlesFilter,
				.timelineTrackingSeparator,
				.markRead,
				.markStar,
				.nextUnread,
				.readerView,
				.share,
				.openInBrowser,
				.flexibleSpace,
				.search
			]
		} else {
			return [
				.newFeed,
				.newFolder,
				.refresh,
				.flexibleSpace,
				.markAllAsRead,
				.search,
				.flexibleSpace,
				.nextUnread,
				.markStar,
				.markRead,
				.readerView,
				.openInBrowser,
				.share
			]
		}
	}
	
	func toolbarWillAddItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if item.itemIdentifier == .share, let button = item.view as? NSButton {
			// The share button should send its action on mouse down, not mouse up.
			button.sendAction(on: .leftMouseDown)
		}

		if #available(macOS 11.0, *) {
			if item.itemIdentifier == .search, let searchItem = item as? NSSearchToolbarItem {
				searchItem.searchField.delegate = self
				searchItem.searchField.target = self
				searchItem.searchField.action = #selector(runSearch(_:))
				currentSearchField = searchItem.searchField
			}
		} else {
			if item.itemIdentifier == .search, let searchField = item.view as? NSSearchField {
				searchField.delegate = self
				searchField.target = self
				searchField.action = #selector(runSearch(_:))
				currentSearchField = searchField
			}
		}
	}

	func toolbarDidRemoveItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if #available(macOS 11.0, *) {
			if item.itemIdentifier == .search, let searchItem = item as? NSSearchToolbarItem {
				searchItem.searchField.delegate = nil
				searchItem.searchField.target = nil
				searchItem.searchField.action = nil
				currentSearchField = nil
			}
		} else {
			if item.itemIdentifier == .search, let searchField = item.view as? NSSearchField {
				searchField.delegate = nil
				searchField.target = nil
				searchField.action = nil
				currentSearchField = nil
			}
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
		state[UserInfoKey.windowFullScreenState] = window?.styleMask.contains(.fullScreen) ?? false
		saveSplitViewState(to: &state)
		sidebarViewController?.saveState(to: &state)
		timelineContainerViewController?.saveState(to: &state)
		return state
	}

	func restoreState(from state: [AnyHashable : Any]) {
		if let fullScreen = state[UserInfoKey.windowFullScreenState] as? Bool, fullScreen {
			window?.toggleFullScreen(self)
		}
		restoreSplitViewState(from: state)
		sidebarViewController?.restoreState(from: state)
		timelineContainerViewController?.restoreState(from: state)
	}

	// MARK: - Command Validation
	
	func canCopyArticleURL() -> Bool {
		return currentLink != nil
	}
	
	func canCopyExternalURL() -> Bool {
		return oneSelectedArticle?.externalURL != nil && oneSelectedArticle?.externalURL != currentLink
	}

	func canGoToNextUnread(wrappingToTop wrapping: Bool = false) -> Bool {
		
		guard let timelineViewController = currentTimelineViewController, let sidebarViewController = sidebarViewController else {
			return false
		}
		// TODO: handle search mode
		return timelineViewController.canGoToNextUnread(wrappingToTop: wrapping) || sidebarViewController.canGoToNextUnread(wrappingToTop: wrapping)
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
		
		if #available(macOS 11.0, *), let toolbarItem = item as? NSToolbarItem, let button = toolbarItem.view as? NSButton {
			button.image = markingRead ? AppAssets.readClosedImage : AppAssets.readOpenImage
		}
		
		return result
	}

	func validateToggleArticleExtractor(_ item: NSValidatedUserInterfaceItem) -> Bool {
		guard !AppDefaults.shared.isDeveloperBuild else {
			return false
		}
		

		if #available(macOS 11.0, *) {

			guard let toolbarItem = item as? NSToolbarItem, let toolbarButton = toolbarItem.view as? ArticleExtractorButton else {
				if let menuItem = item as? NSMenuItem {
					menuItem.state = isShowingExtractedArticle ? .on : .off
				}
				return currentLink != nil
			}
			
			if let webfeed = currentTimelineViewController?.selectedArticles.first?.webFeed {
				if webfeed.isFeedProvider {
					toolbarButton.isEnabled = false
					return false
				} else {
					toolbarButton.isEnabled = true
				}
			}

			guard let state = articleExtractor?.state else {
				toolbarButton.buttonState = .off
				return currentLink != nil
			}

			switch state {
			case .processing:
				toolbarButton.buttonState = .animated
			case .failedToParse:
				toolbarButton.buttonState = .error
			case .ready, .cancelled, .complete:
				toolbarButton.buttonState = isShowingExtractedArticle ? .on : .off
			}

		} else {
			
			guard let toolbarItem = item as? NSToolbarItem, let toolbarButton = toolbarItem.view as? LegacyArticleExtractorButton else {
				if let menuItem = item as? NSMenuItem {
					menuItem.state = isShowingExtractedArticle ? .on : .off
				}
				return currentLink != nil
			}
			
			if let webfeed = currentTimelineViewController?.selectedArticles.first?.webFeed {
				if webfeed.isFeedProvider {
					toolbarButton.isEnabled = false
					return false
				} else {
					toolbarButton.isEnabled = true
				}
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
		}

		if let menuItem = item as? NSMenuItem {
			menuItem.title = commandName
		}

		if #available(macOS 11.0, *), let toolbarItem = item as? NSToolbarItem, let button = toolbarItem.view as? NSButton {
			button.image = starring ? AppAssets.starOpenImage : AppAssets.starClosedImage
		}

		return result
	}
	
	func validateCleanUp(_ item: NSValidatedUserInterfaceItem) -> Bool {
		return timelineContainerViewController?.isCleanUpAvailable ?? false
	}

	func validateToggleReadFeeds(_ item: NSValidatedUserInterfaceItem) -> Bool {
		guard let menuItem = item as? NSMenuItem else { return false }

		let showCommand = NSLocalizedString("Show Read Feeds", comment: "Command")
		let hideCommand = NSLocalizedString("Hide Read Feeds", comment: "Command")
		menuItem.title = sidebarViewController?.isReadFiltered ?? false ? showCommand : hideCommand
		return true
	}

	func validateToggleReadArticles(_ item: NSValidatedUserInterfaceItem) -> Bool {
		let showCommand = NSLocalizedString("Show Read Articles", comment: "Command")
		let hideCommand = NSLocalizedString("Hide Read Articles", comment: "Command")

		guard let isReadFiltered = timelineContainerViewController?.isReadFiltered else {
			(item as? NSMenuItem)?.title = hideCommand
			if #available(macOS 11.0, *), let toolbarItem = item as? NSToolbarItem, let button = toolbarItem.view as? NSButton {
				toolbarItem.toolTip = hideCommand
				button.image = AppAssets.filterInactive
			}
			return false
		}

		if isReadFiltered {
			(item as? NSMenuItem)?.title = showCommand
			if #available(macOS 11.0, *), let toolbarItem = item as? NSToolbarItem, let button = toolbarItem.view as? NSButton {
				toolbarItem.toolTip = showCommand
				button.image = AppAssets.filterActive
			}
		} else {
			(item as? NSMenuItem)?.title = hideCommand
			if #available(macOS 11.0, *), let toolbarItem = item as? NSToolbarItem, let button = toolbarItem.view as? NSButton {
				toolbarItem.toolTip = hideCommand
				button.image = AppAssets.filterInactive
			}
		}
		
		return true
	}

	// MARK: - Misc.

	func goToNextUnreadInTimeline(wrappingToTop wrapping: Bool) {

		guard let timelineViewController = currentTimelineViewController else {
			return
		}

		if timelineViewController.canGoToNextUnread(wrappingToTop: wrapping) {
			timelineViewController.goToNextUnread(wrappingToTop: wrapping)
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
		guard timelineSourceMode != .search else {
			let localizedLabel = NSLocalizedString("Search: %@", comment: "Search")
			window?.title = NSString.localizedStringWithFormat(localizedLabel as NSString, searchString ?? "") as String
			if #available(macOS 11.0, *) {
				window?.subtitle = ""
			}
			return
		}
		
		func setSubtitle(_ count: Int) {
			let localizedLabel = NSLocalizedString("%d unread", comment: "Unread")
			let formattedLabel = NSString.localizedStringWithFormat(localizedLabel as NSString, count)
			if #available(macOS 11.0, *) {
				window?.subtitle = formattedLabel as String
			}
		}
		
		guard let selectedObjects = selectedObjectsInSidebar(), selectedObjects.count > 0 else {
			window?.title = appDelegate.appName!
			if #available(macOS 11.0, *) {
				setSubtitle(appDelegate.unreadCount)
			}
			return
		}
		
		guard selectedObjects.count == 1 else {
			window?.title = NSLocalizedString("Multiple", comment: "Multiple")
			if #available(macOS 11.0, *) {
				let unreadCount = selectedObjects.reduce(0, { result, selectedObject in
					if let unreadCountProvider = selectedObject as? UnreadCountProvider {
						return result + unreadCountProvider.unreadCount
					} else {
						return result
					}
				})
				setSubtitle(unreadCount)
			}
			return
		}
		
		if let displayNameProvider = currentFeedOrFolder as? DisplayNameProvider {
			window?.title = displayNameProvider.nameForDisplay
			if #available(macOS 11.0, *) {
				if let unreadCountProvider = currentFeedOrFolder as? UnreadCountProvider {
					setSubtitle(unreadCountProvider.unreadCount)
				}
			}
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

	func buildToolbarButton(_ itemIdentifier: NSToolbarItem.Identifier, _ title: String, _ image: NSImage, _ selector: String) -> NSToolbarItem {
		let toolbarItem = RSToolbarItem(itemIdentifier: itemIdentifier)
		toolbarItem.autovalidates = true
		
		let button = NSButton()
		button.bezelStyle = .texturedRounded
		button.image = image
		button.imageScaling = .scaleProportionallyDown
		button.action = Selector((selector))
		
		toolbarItem.view = button
		toolbarItem.toolTip = title
		toolbarItem.label = title
		return toolbarItem
	}

	func buildNewSidebarItemMenu() -> NSMenu {
		let menu = NSMenu()
		
		let newWebFeedItem = NSMenuItem()
		newWebFeedItem.title = NSLocalizedString("New Web Feed", comment: "New Web Feed")
		newWebFeedItem.action = Selector(("showAddWebFeedWindow:"))
		menu.addItem(newWebFeedItem)
		
		let newRedditFeedItem = NSMenuItem()
		newRedditFeedItem.title = NSLocalizedString("New Reddit Feed", comment: "New Reddit Feed")
		newRedditFeedItem.action = Selector(("showAddRedditFeedWindow:"))
		menu.addItem(newRedditFeedItem)
		
		let newTwitterFeedItem = NSMenuItem()
		newTwitterFeedItem.title = NSLocalizedString("New Twitter Feed", comment: "New Twitter Feed")
		newTwitterFeedItem.action = Selector(("showAddTwitterFeedWindow:"))
		menu.addItem(newTwitterFeedItem)
		
		let newFolderFeedItem = NSMenuItem()
		newFolderFeedItem.title = NSLocalizedString("New Folder", comment: "New Folder")
		newFolderFeedItem.action = Selector(("showAddFolderWindow:"))
		menu.addItem(newFolderFeedItem)
		
		return menu
	}

}

