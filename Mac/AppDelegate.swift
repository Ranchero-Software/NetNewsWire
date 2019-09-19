//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/11/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles
import RSTree
import RSWeb
import Account
import RSCore

var appDelegate: AppDelegate!

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations, UnreadCountProvider {

	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var feedIconDownloader: FeedIconDownloader!
	var appName: String!
	
	var refreshTimer: AccountRefreshTimer?
	var syncTimer: ArticleStatusSyncTimer?
	
	var shuttingDown = false {
		didSet {
			if shuttingDown {
				refreshTimer?.shuttingDown = shuttingDown
				refreshTimer?.invalidate()
				syncTimer?.shuttingDown = shuttingDown
				syncTimer?.invalidate()
			}
		}
	}

	@IBOutlet var debugMenuItem: NSMenuItem!
	@IBOutlet var sortByOldestArticleOnTopMenuItem: NSMenuItem!
	@IBOutlet var sortByNewestArticleOnTopMenuItem: NSMenuItem!
	@IBOutlet var groupArticlesByFeedMenuItem: NSMenuItem!
	@IBOutlet var checkForUpdatesMenuItem: NSMenuItem!

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				CoalescingQueue.standard.add(self, #selector(updateDockBadge))
				postUnreadCountDidChangeNotification()
			}
		}
	}

	private var preferencesWindowController: NSWindowController?
	private var mainWindowController: MainWindowController?
	private var addFeedController: AddFeedController?
	private var addFolderWindowController: AddFolderWindowController?
	private var importOPMLController: ImportOPMLWindowController?
	private var exportOPMLController: ExportOPMLWindowController?
	private var keyboardShortcutsWindowController: WebViewWindowController?
	private var inspectorWindowController: InspectorWindowController?
	private var crashReportWindowController: CrashReportWindowController? // For testing only
	private let log = Log()
	private let appNewsURLString = "https://nnw.ranchero.com/feed.json"
	private let appMovementMonitor = RSAppMovementMonitor()

	override init() {
		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()

		AccountManager.shared = AccountManager(accountsFolder: RSDataSubfolder(nil, "Accounts")!)
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(inspectableObjectsDidChange(_:)), name: .InspectableObjectsDidChange, object: nil)

		appDelegate = self
	}

	// MARK: - API

	func logMessage(_ message: String, type: LogItem.ItemType) {

		#if DEBUG
		if type == .debug {
			print("logMessage: \(message) - \(type)")
		}
		#endif

		let logItem = LogItem(type: type, message: message)
		log.add(logItem)
	}

	func logDebugMessage(_ message: String) {

		logMessage(message, type: .debug)
	}

	func showAddFolderSheetOnWindow(_ window: NSWindow) {

		addFolderWindowController = AddFolderWindowController()
		addFolderWindowController!.runSheetOnWindow(window)
	}

	func showAddFeedSheetOnWindow(_ window: NSWindow, urlString: String?, name: String?, account: Account?, folder: Folder?) {

		addFeedController = AddFeedController(hostWindow: window)
		addFeedController?.showAddFeedSheet(urlString, name, account, folder)
	}
	
	// MARK: - NSApplicationDelegate

	func applicationWillFinishLaunching(_ notification: Notification) {
		installAppleEventHandlers()
	}
	
	func applicationDidFinishLaunching(_ note: Notification) {

		#if MAC_APP_STORE
			checkForUpdatesMenuItem.isHidden = true
		#endif
		
		appName = (Bundle.main.infoDictionary!["CFBundleExecutable"]! as! String)

		AppDefaults.registerDefaults()
		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			logDebugMessage("Is first run.")
		}
		let localAccount = AccountManager.shared.defaultAccount
		DefaultFeedsImporter.importIfNeeded(isFirstRun, account: localAccount)

		let tempDirectory = NSTemporaryDirectory()
		let bundleIdentifier = (Bundle.main.infoDictionary!["CFBundleIdentifier"]! as! String)
		let cacheFolder = (tempDirectory as NSString).appendingPathComponent(bundleIdentifier)

		// If the image disk cache hasn't been flushed for 3 days and the network is available, delete it
		if let flushDate = AppDefaults.lastImageCacheFlushDate, flushDate.addingTimeInterval(3600*24*3) < Date() {
			if let reachability = try? Reachability(hostname: "apple.com") {
				if reachability.connection != .unavailable {
					try? FileManager.default.removeItem(atPath: cacheFolder)
					AppDefaults.lastImageCacheFlushDate = Date()
				}
			}
		}
		
		let faviconsFolder = (cacheFolder as NSString).appendingPathComponent("Favicons")
		let faviconsFolderURL = URL(fileURLWithPath: faviconsFolder)
		try! FileManager.default.createDirectory(at: faviconsFolderURL, withIntermediateDirectories: true, attributes: nil)
		faviconDownloader = FaviconDownloader(folder: faviconsFolder)

		let imagesFolder = (cacheFolder as NSString).appendingPathComponent("Images")
		let imagesFolderURL = URL(fileURLWithPath: imagesFolder)
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
		imageDownloader = ImageDownloader(folder: imagesFolder)

		authorAvatarDownloader = AuthorAvatarDownloader(imageDownloader: imageDownloader)
		feedIconDownloader = FeedIconDownloader(imageDownloader: imageDownloader, folder: cacheFolder)

		updateSortMenuItems()
		updateGroupByFeedMenuItem()
        createAndShowMainWindow()
		if isFirstRun {
			mainWindowController?.window?.center()
		}

		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		if InspectorWindowController.shouldOpenAtStartup {
			self.toggleInspectorWindow(self)
		}

		refreshTimer = AccountRefreshTimer()
		syncTimer = ArticleStatusSyncTimer()
		
		#if RELEASE
			debugMenuItem.menu?.removeItem(debugMenuItem)
			DispatchQueue.main.async {
				self.refreshTimer!.timedRefresh(nil)
				self.syncTimer!.timedRefresh(nil)
			}
		#endif

		#if DEBUG
			refreshTimer!.update()
			syncTimer!.update()
		#endif

		#if !MAC_APP_STORE
			DispatchQueue.main.async {
				CrashReporter.check(appName: "NetNewsWire")
			}
		#endif
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		// https://github.com/brentsimmons/NetNewsWire/issues/522
		// I couldn’t reproduce the crashing bug, but it appears to happen on creating a main window
		// and its views and view controllers. The check below is so that the app does nothing
		// if the window doesn’t already exist — because it absolutely *should* exist already.
		// And if the window exists, then maybe the views and view controllers are also already loaded?
		// We’ll try this, and then see if we get more crash logs like this or not.
		guard let mainWindowController = mainWindowController, mainWindowController.isWindowLoaded else {
			return false
		}
		mainWindowController.showWindow(self)
		return false
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		// It’s possible there’s a refresh timer set to go off in the past.
		// In that case, refresh now and update the timer.
		refreshTimer?.fireOldTimer()
		syncTimer?.fireOldTimer()
	}
	
	func applicationDidResignActive(_ notification: Notification) {

		TimelineStringFormatter.emptyCaches()

		saveState()
	}

	func applicationWillTerminate(_ notification: Notification) {
		shuttingDown = true
		saveState()
		
		let group = DispatchGroup()
		
		group.enter()
		AccountManager.shared.syncArticleStatusAll() {
			group.leave()
		}
		
		let timeout = DispatchTime.now() + .seconds(1)
		_ = group.wait(timeout: timeout)
	}

	// MARK: Notifications

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	@objc func feedSettingDidChange(_ note: Notification) {

		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.FeedSettingUserInfoKey] as? String else {
			return
		}
		if key == Feed.FeedSettingKey.homePageURL || key == Feed.FeedSettingKey.faviconURL {
			let _ = faviconDownloader.favicon(for: feed)
		}
	}

	@objc func inspectableObjectsDidChange(_ note: Notification) {

		guard let inspectorWindowController = inspectorWindowController, inspectorWindowController.isOpen else {
			return
		}
		inspectorWindowController.objects = objectsForInspector()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		updateSortMenuItems()
		updateGroupByFeedMenuItem()
		refreshTimer?.update()
		updateDockBadge()
	}

	// MARK: Main Window

	func windowControllerWithName(_ storyboardName: String) -> NSWindowController {

		let storyboard = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
		return storyboard.instantiateInitialController()! as! NSWindowController
	}

	func createAndShowMainWindow() {

		if mainWindowController == nil {
			mainWindowController = createReaderWindow()
		}

		mainWindowController!.showWindow(self)
	}

	// MARK: NSUserInterfaceValidations

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		if shuttingDown {
			return false
		}

		let isDisplayingSheet = mainWindowController?.isDisplayingSheet ?? false

		if item.action == #selector(refreshAll(_:)) {
			return !AccountManager.shared.refreshInProgress && !AccountManager.shared.activeAccounts.isEmpty
		}
		if item.action == #selector(addAppNews(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) && !AccountManager.shared.activeAccounts.isEmpty
		}
		if item.action == #selector(sortByNewestArticleOnTop(_:)) || item.action == #selector(sortByOldestArticleOnTop(_:)) {
			return mainWindowController?.isOpen ?? false
		}
		if item.action == #selector(showAddFeedWindow(_:)) || item.action == #selector(showAddFolderWindow(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.activeAccounts.isEmpty
		}
		#if !MAC_APP_STORE
		if item.action == #selector(toggleWebInspectorEnabled(_:)) {
			(item as! NSMenuItem).state = AppDefaults.webInspectorEnabled ? .on : .off
		}
		#endif
		return true
	}

	// MARK: Add Feed

	func addFeed(_ urlString: String?, name: String? = nil, account: Account? = nil, folder: Folder? = nil) {

		createAndShowMainWindow()
		if mainWindowController!.isDisplayingSheet {
			return
		}

		showAddFeedSheetOnWindow(mainWindowController!.window!, urlString: urlString, name: name, account: account, folder: folder)
	}

	// MARK: - Dock Badge

	@objc func updateDockBadge() {
		let label = unreadCount > 0 && !AppDefaults.hideDockUnreadCount ? "\(unreadCount)" : ""
		NSApplication.shared.dockTile.badgeLabel = label
	}

	// MARK: - Actions

	@IBAction func showPreferences(_ sender: Any?) {

		if preferencesWindowController == nil {
			preferencesWindowController = windowControllerWithName("Preferences")
		}

		preferencesWindowController!.showWindow(self)
	}

	@IBAction func showMainWindow(_ sender: Any?) {

		createAndShowMainWindow()
	}

	@IBAction func refreshAll(_ sender: Any?) {

		AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present)
	}

	@IBAction func showAddFeedWindow(_ sender: Any?) {

		addFeed(nil)
	}

	@IBAction func showAddFolderWindow(_ sender: Any?) {

		createAndShowMainWindow()
		showAddFolderSheetOnWindow(mainWindowController!.window!)
	}

	@IBAction func showKeyboardShortcutsWindow(_ sender: Any?) {

		if keyboardShortcutsWindowController == nil {
			keyboardShortcutsWindowController = WebViewWindowController(title: NSLocalizedString("Keyboard Shortcuts", comment: "window title"))
			let htmlFile = Bundle(for: type(of: self)).path(forResource: "KeyboardShortcuts", ofType: "html")!
			keyboardShortcutsWindowController?.displayContents(of: htmlFile)

			if let window = keyboardShortcutsWindowController?.window {
				let point = NSPoint(x: 128, y: 64)
				let size = NSSize(width: 620, height: 1100)
				let minSize = NSSize(width: 400, height: 400)
				window.setPointAndSizeAdjustingForScreen(point: point, size: size, minimumSize: minSize)
			}
		}

		keyboardShortcutsWindowController!.showWindow(self)
	}

	@IBAction func toggleInspectorWindow(_ sender: Any?) {

		if inspectorWindowController == nil {
			inspectorWindowController = (windowControllerWithName("Inspector") as! InspectorWindowController)
		}

		if inspectorWindowController!.isOpen {
			inspectorWindowController!.window!.performClose(self)
		}
		else {
			inspectorWindowController!.objects = objectsForInspector()
			inspectorWindowController!.showWindow(self)
		}
	}

	@IBAction func importOPMLFromFile(_ sender: Any?) {

		createAndShowMainWindow()
		if mainWindowController!.isDisplayingSheet {
			return
		}
		
		importOPMLController = ImportOPMLWindowController()
		importOPMLController?.runSheetOnWindow(mainWindowController!.window!)
		
	}
	
	@IBAction func exportOPML(_ sender: Any?) {

		createAndShowMainWindow()
		if mainWindowController!.isDisplayingSheet {
			return
		}
		
		exportOPMLController = ExportOPMLWindowController()
		exportOPMLController?.runSheetOnWindow(mainWindowController!.window!)
		
	}
	
	@IBAction func addAppNews(_ sender: Any?) {

		if AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) {
			return
		}
		addFeed(appNewsURLString, name: "NetNewsWire News")
	}

	@IBAction func openWebsite(_ sender: Any?) {

		Browser.open("https://ranchero.com/netnewswire/", inBackground: false)
	}

	@IBAction func openHowToSupport(_ sender: Any?) {
		
		Browser.open("https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown", inBackground: false)
	}
	
	@IBAction func openRepository(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire", inBackground: false)
	}

	@IBAction func openBugTracker(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire/issues", inBackground: false)
	}

	@IBAction func openSlackGroup(_ sender: Any?) {
		Browser.open("https://join.slack.com/t/netnewswire/shared_invite/enQtNjM4MDA1MjQzMDkzLTNlNjBhOWVhYzdhYjA4ZWFhMzQ1MTUxYjU0NTE5ZGY0YzYwZWJhNjYwNTNmNTg2NjIwYWY4YzhlYzk5NmU3ZTc", inBackground: false)
	}

	@IBAction func openTechnotes(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes", inBackground: false)
	}

	@IBAction func showHelp(_ sender: Any?) {

		Browser.open("https://ranchero.com/netnewswire/help/mac/5.0/en/", inBackground: false)
	}

	@IBAction func donateToAppCampForGirls(_ sender: Any?) {
		Browser.open("https://appcamp4girls.com/contribute/", inBackground: false)
	}

	@IBAction func showPrivacyPolicy(_ sender: Any?) {
		Browser.open("https://ranchero.com/netnewswire/privacypolicy", inBackground: false)
	}

	@IBAction func debugDropConditionalGetInfo(_ sender: Any?) {
		#if DEBUG
			AccountManager.shared.activeAccounts.forEach{ $0.debugDropConditionalGetInfo() }
		#endif
	}

	@IBAction func debugTestCrashReporterWindow(_ sender: Any?) {
		#if DEBUG
			crashReportWindowController = CrashReportWindowController(crashLogText: "This is a test crash log.")
			crashReportWindowController!.testing = true
			crashReportWindowController!.showWindow(self)
		#endif
	}

	@IBAction func debugTestCrashReportSending(_ sender: Any?) {
		#if DEBUG
			CrashReporter.sendCrashLogText("This is a test. Hi, Brent.")
		#endif
	}

	@IBAction func gotoToday(_ sender: Any?) {

		createAndShowMainWindow()
		mainWindowController!.gotoToday(sender)
	}

	@IBAction func gotoAllUnread(_ sender: Any?) {

		createAndShowMainWindow()
		mainWindowController!.gotoAllUnread(sender)
	}

	@IBAction func gotoStarred(_ sender: Any?) {

		createAndShowMainWindow()
		mainWindowController!.gotoStarred(sender)
	}

	@IBAction func sortByOldestArticleOnTop(_ sender: Any?) {

		AppDefaults.timelineSortDirection = .orderedAscending
	}

	@IBAction func sortByNewestArticleOnTop(_ sender: Any?) {

		AppDefaults.timelineSortDirection = .orderedDescending
	}
	
	@IBAction func groupByFeedToggled(_ sender: NSMenuItem) {		
		AppDefaults.timelineGroupByFeed.toggle()
	}
	
}

// MARK: - Debug Menu
extension AppDelegate {

	@IBAction func debugSearch(_ sender: Any?) {
		AccountManager.shared.defaultAccount.debugRunSearch()
	}

	@IBAction func toggleWebInspectorEnabled(_ sender: Any?) {
		#if !MAC_APP_STORE
			let newValue = !AppDefaults.webInspectorEnabled
			AppDefaults.webInspectorEnabled = newValue

			// An attached inspector can display incorrectly on certain setups (like mine); default to displaying in a separate window,
			// and reset the default to a separate window when the preference is toggled off and on again in case the inspector is
			// accidentally reattached.

			AppDefaults.webInspectorStartsAttached = false
			NotificationCenter.default.post(name: .WebInspectorEnabledDidChange, object: newValue)
		#endif
	}
}

private extension AppDelegate {

	func createReaderWindow() -> MainWindowController {

		return windowControllerWithName("MainWindow") as! MainWindowController
	}

	func objectsForInspector() -> [Any]? {

		guard let window = NSApplication.shared.mainWindow, let windowController = window.windowController as? MainWindowController else {
			return nil
		}
		return windowController.selectedObjectsInSidebar()
	}

	func saveState() {

		inspectorWindowController?.saveState()
		mainWindowController?.saveState()
	}

	func updateSortMenuItems() {

		let sortByNewestOnTop = AppDefaults.timelineSortDirection == .orderedDescending
		sortByNewestArticleOnTopMenuItem.state = sortByNewestOnTop ? .on : .off
		sortByOldestArticleOnTopMenuItem.state = sortByNewestOnTop ? .off : .on
	}
	
	func updateGroupByFeedMenuItem() {
		let groupByFeedEnabled = AppDefaults.timelineGroupByFeed
		groupArticlesByFeedMenuItem.state = groupByFeedEnabled ? .on : .off
	}
}

/*
    the ScriptingAppDelegate protocol exposes a narrow set of accessors with
    internal visibility which are very similar to some private vars.
    
    These would be unnecessary if the similar accessors were marked internal rather than private,
    but for now, we'll keep the stratification of visibility
*/
extension AppDelegate : ScriptingAppDelegate {

    internal var scriptingMainWindowController: ScriptingMainWindowController? {
        return mainWindowController
    }

    internal var  scriptingCurrentArticle: Article? {
        return self.scriptingMainWindowController?.scriptingCurrentArticle
    }

    internal var  scriptingSelectedArticles: [Article] {
        return self.scriptingMainWindowController?.scriptingSelectedArticles ?? []
    }
}
