//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/11/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import UserNotifications
import Articles
import RSTree
import RSWeb
import Account
import RSCore
import RSCoreResources
import Secrets
import OSLog
import CrashReporter

// If we're not going to import Sparkle, provide dummy protocols to make it easy
// for AppDelegate to comply
#if MAC_APP_STORE || TEST
protocol SPUStandardUserDriverDelegate {}
protocol SPUUpdaterDelegate {}
#else
import Sparkle
#endif

var appDelegate: AppDelegate!

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations, UNUserNotificationCenterDelegate, UnreadCountProvider, SPUStandardUserDriverDelegate, SPUUpdaterDelegate
{

	private struct WindowRestorationIdentifiers {
		static let mainWindow = "mainWindow"
	}
	
	var userNotificationManager: UserNotificationManager!
	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var webFeedIconDownloader: WebFeedIconDownloader!
	var extensionContainersFile: ExtensionContainersFile!
	var extensionFeedAddRequestFile: ExtensionFeedAddRequestFile!

	var appName: String!
	
	var refreshTimer: AccountRefreshTimer?
	var syncTimer: ArticleStatusSyncTimer?
	var lastRefreshInterval = AppDefaults.shared.refreshInterval
	
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

	var isShutDownSyncDone = false
	
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

	private var mainWindowController: MainWindowController? {
		var bestController: MainWindowController?
		for candidateController in mainWindowControllers {
			if let bestWindow = bestController?.window, let candidateWindow = candidateController.window {
				if bestWindow.orderedIndex > candidateWindow.orderedIndex {
					bestController = candidateController
				}
			} else {
				bestController = candidateController
			}
		}
		return bestController
	}
	
	private var mainWindowControllers = [MainWindowController]()
	private var preferencesWindowController: NSWindowController?
	private var addFeedController: AddFeedController?
	private var addFolderWindowController: AddFolderWindowController?
	private var importOPMLController: ImportOPMLWindowController?
	private var exportOPMLController: ExportOPMLWindowController?
	private var keyboardShortcutsWindowController: WebViewWindowController?
	private var inspectorWindowController: InspectorWindowController?
	private var crashReportWindowController: CrashReportWindowController? // For testing only
	private let appMovementMonitor = RSAppMovementMonitor()
	#if !MAC_APP_STORE && !TEST
	private var softwareUpdater: SPUUpdater!
	private var crashReporter: PLCrashReporter!
	#endif
	
	private var themeImportPath: String?

	override init() {
		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()

		#if !MAC_APP_STORE
		let crashReporterConfig = PLCrashReporterConfig.defaultConfiguration()
		crashReporter = PLCrashReporter(configuration: crashReporterConfig)
		crashReporter.enable()
		#endif

		SecretsManager.provider = Secrets()
		AccountManager.shared = AccountManager(accountsFolder: Platform.dataSubfolder(forApplication: nil, folderName: "Accounts")!)
		ArticleThemesManager.shared = ArticleThemesManager(folderPath: Platform.dataSubfolder(forApplication: nil, folderName: "Themes")!)
		FeedProviderManager.shared.delegate = ExtensionPointManager.shared

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(inspectableObjectsDidChange(_:)), name: .InspectableObjectsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(importDownloadedTheme(_:)), name: .didEndDownloadingTheme, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(themeImportError(_:)), name: .didFailToImportThemeWithError, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWakeNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)

		appDelegate = self
	}

	// MARK: - API
	func showAddFolderSheetOnWindow(_ window: NSWindow) {
		addFolderWindowController = AddFolderWindowController()
		addFolderWindowController!.runSheetOnWindow(window)
	}

	func showAddWebFeedSheetOnWindow(_ window: NSWindow, urlString: String?, name: String?, account: Account?, folder: Folder?) {
		addFeedController = AddFeedController(hostWindow: window)
		addFeedController?.showAddFeedSheet(.webFeed, urlString, name, account, folder)
	}
	
	// MARK: - NSApplicationDelegate
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		installAppleEventHandlers()
		
		CacheCleaner.purgeIfNecessary()

		// Try to establish a cache in the Caches folder, but if it fails for some reason fall back to a temporary dir
		let cacheFolder: String
		if let userCacheFolder = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false).path {
			cacheFolder = userCacheFolder
		}
		else {
			let bundleIdentifier = (Bundle.main.infoDictionary!["CFBundleIdentifier"]! as! String)
			cacheFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent(bundleIdentifier)
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
		webFeedIconDownloader = WebFeedIconDownloader(imageDownloader: imageDownloader, folder: cacheFolder)

		appName = (Bundle.main.infoDictionary!["CFBundleExecutable"]! as! String)
	}
	
	func applicationDidFinishLaunching(_ note: Notification) {

		#if MAC_APP_STORE || TEST
			checkForUpdatesMenuItem.isHidden = true
		#else
			// Initialize Sparkle...
			let hostBundle = Bundle.main
			let updateDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: self)
			self.softwareUpdater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: updateDriver, delegate: self)

			do {
				try self.softwareUpdater.start()
			}
			catch {
				NSLog("Failed to start software updater with error: \(error)")
			}
		#endif
		
		AppDefaults.shared.registerDefaults()
		let isFirstRun = AppDefaults.shared.isFirstRun
		if isFirstRun {
			os_log(.debug, "Is first run.")
		}
		let localAccount = AccountManager.shared.defaultAccount

		if isFirstRun && !AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			// Import feeds. Either old NNW 3 feeds or the default feeds.
			if !NNW3ImportController.importSubscriptionsIfFileExists(account: localAccount) {
				DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
			}
		}

		updateSortMenuItems()
		updateGroupByFeedMenuItem()
		
		if mainWindowController == nil {
			let mainWindowController = createAndShowMainWindow()
			mainWindowController.restoreStateFromUserDefaults()
		}
		
		if isFirstRun {
			mainWindowController?.window?.center()
		}

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedSettingDidChange(_:)), name: .WebFeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		if InspectorWindowController.shouldOpenAtStartup {
			self.toggleInspectorWindow(self)
		}

		extensionContainersFile = ExtensionContainersFile()
		extensionFeedAddRequestFile = ExtensionFeedAddRequestFile()

		refreshTimer = AccountRefreshTimer()
		syncTimer = ArticleStatusSyncTimer()
		
		UNUserNotificationCenter.current().requestAuthorization(options:[.badge]) { (granted, error) in }

		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		userNotificationManager = UserNotificationManager()

		#if DEBUG
		refreshTimer!.update()
		syncTimer!.update()
		#else
		if AppDefaults.shared.suppressSyncOnLaunch {
			refreshTimer!.update()
			syncTimer!.update()
		} else {
			DispatchQueue.main.async {
				self.refreshTimer!.timedRefresh(nil)
				self.syncTimer!.timedRefresh(nil)
			}
		}
		#endif
		
		if AppDefaults.shared.showDebugMenu {
  			// The Web Inspector uses SPI and can never appear in a MAC_APP_STORE build.
 			#if MAC_APP_STORE
 			let debugMenu = debugMenuItem.submenu!
 			let toggleWebInspectorItemIndex = debugMenu.indexOfItem(withTarget: self, andAction: #selector(toggleWebInspectorEnabled(_:)))
 			if toggleWebInspectorItemIndex != -1 {
 				debugMenu.removeItem(at: toggleWebInspectorItemIndex)
 			}
 			#endif
 		} else {
			debugMenuItem.menu?.removeItem(debugMenuItem)
		}

		#if !MAC_APP_STORE
		DispatchQueue.main.async {
			CrashReporter.check(crashReporter: self.crashReporter)
		}
		#endif
		
	}
	
	func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
		guard let mainWindowController = mainWindowController else {
			return false
		}
		mainWindowController.handle(userActivity)
		return true
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
		fireOldTimers()
	}
	
	func applicationDidResignActive(_ notification: Notification) {
		ArticleStringFormatter.emptyCaches()
		saveState()
	}

	func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
		AccountManager.shared.receiveRemoteNotification(userInfo: userInfo)
	}
	
	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		guard filename.hasSuffix(ArticleTheme.nnwThemeSuffix) else { return false }
		importTheme(filename: filename)
		return true
	}
	
	func applicationWillTerminate(_ notification: Notification) {
		shuttingDown = true
		saveState()
		
		ArticleThemeDownloader.shared.cleanUp()
		
		AccountManager.shared.sendArticleStatusAll() {
			self.isShutDownSyncDone = true
		}
		
		let timeout = Date().addingTimeInterval(2)
		while !isShutDownSyncDone && RunLoop.current.run(mode: .default, before: timeout) && timeout > Date() { }
	}

	// MARK: Notifications
	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	@objc func webFeedSettingDidChange(_ note: Notification) {
		guard let feed = note.object as? WebFeed, let key = note.userInfo?[WebFeed.WebFeedSettingUserInfoKey] as? String else {
			return
		}
		if key == WebFeed.WebFeedSettingKey.homePageURL || key == WebFeed.WebFeedSettingKey.faviconURL {
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
		
		if lastRefreshInterval != AppDefaults.shared.refreshInterval {
			refreshTimer?.update()
			lastRefreshInterval = AppDefaults.shared.refreshInterval
		}
		
		updateDockBadge()
	}
	
	@objc func didWakeNotification(_ note: Notification) {
		fireOldTimers()
	}
	
	@objc func importDownloadedTheme(_ note: Notification) {
		guard let userInfo = note.userInfo,
			let url = userInfo["url"] as? URL else {
			return
		}
		DispatchQueue.main.async {
			self.importTheme(filename: url.path)
		}
	}

	// MARK: Main Window
	
	func createMainWindowController() -> MainWindowController {
		let controller: MainWindowController
		controller = windowControllerWithName("MainWindow") as! MainWindowController
		
		if !(mainWindowController?.isOpen ?? false) {
			mainWindowControllers.removeAll()
		}
		mainWindowControllers.append(controller)
		return controller
	}

	func windowControllerWithName(_ storyboardName: String) -> NSWindowController {
		let storyboard = NSStoryboard(name: NSStoryboard.Name(storyboardName), bundle: nil)
		return storyboard.instantiateInitialController()! as! NSWindowController
	}

	@discardableResult
	func createAndShowMainWindow() -> MainWindowController {
		let controller = createMainWindowController()
		controller.showWindow(self)
		
		if let window = controller.window {
			window.restorationClass = Self.self
			window.identifier = NSUserInterfaceItemIdentifier(rawValue: WindowRestorationIdentifiers.mainWindow)
		}
		
		return controller
	}

	func createAndShowMainWindowIfNecessary() {
		if mainWindowController == nil {
			createAndShowMainWindow()
		} else {
			mainWindowController?.showWindow(self)
		}
	}

	func removeMainWindow(_ windowController: MainWindowController) {
		guard mainWindowControllers.count > 1 else { return }
		if let index = mainWindowControllers.firstIndex(of: windowController) {
			mainWindowControllers.remove(at: index)
		}
	}
	
	// MARK: NSUserInterfaceValidations
	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		if shuttingDown {
			return false
		}

		let isDisplayingSheet = mainWindowController?.isDisplayingSheet ?? false
		let isSpecialAccountAvailable = AccountManager.shared.activeAccounts.contains(where: { $0.type == .onMyMac || $0.type == .cloudKit })

		if item.action == #selector(refreshAll(_:)) {
			return !AccountManager.shared.refreshInProgress && !AccountManager.shared.activeAccounts.isEmpty
		}
		
		if item.action == #selector(importOPMLFromFile(_:)) {
			return AccountManager.shared.activeAccounts.contains(where: { !$0.behaviors.contains(where: { $0 == .disallowOPMLImports }) })
		}
		
		if item.action == #selector(addAppNews(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() && !AccountManager.shared.activeAccounts.isEmpty
		}
		
		if item.action == #selector(sortByNewestArticleOnTop(_:)) || item.action == #selector(sortByOldestArticleOnTop(_:)) {
			return mainWindowController?.isOpen ?? false
		}
		
		if item.action == #selector(showAddWebFeedWindow(_:)) || item.action == #selector(showAddFolderWindow(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.activeAccounts.isEmpty
		}
		
		if item.action == #selector(showAddRedditFeedWindow(_:)) {
			guard !isDisplayingSheet && isSpecialAccountAvailable && ExtensionPointManager.shared.isRedditEnabled else {
				return false
			}
			return ExtensionPointManager.shared.isRedditEnabled
		}
		
		if item.action == #selector(showAddTwitterFeedWindow(_:)) {
			guard !isDisplayingSheet && isSpecialAccountAvailable && ExtensionPointManager.shared.isTwitterEnabled else {
				return false
			}
			return ExtensionPointManager.shared.isTwitterEnabled
		}
		
		#if !MAC_APP_STORE
		if item.action == #selector(toggleWebInspectorEnabled(_:)) {
			(item as! NSMenuItem).state = AppDefaults.shared.webInspectorEnabled ? .on : .off
		}
		#endif
		
		return true
	}

	// MARK: UNUserNotificationCenterDelegate
	
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }
	
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		
		let userInfo = response.notification.request.content.userInfo
		
		switch response.actionIdentifier {
		case "MARK_AS_READ":
			handleMarkAsRead(userInfo: userInfo)
		case "MARK_AS_STARRED":
			handleMarkAsStarred(userInfo: userInfo)
		default:
			mainWindowController?.handle(response)
		}
		completionHandler()
    }
	
	// MARK: Add Feed
	func addWebFeed(_ urlString: String?, name: String? = nil, account: Account? = nil, folder: Folder? = nil) {
		createAndShowMainWindowIfNecessary()
		
		if mainWindowController!.isDisplayingSheet {
			return
		}

		showAddWebFeedSheetOnWindow(mainWindowController!.window!, urlString: urlString, name: name, account: account, folder: folder)
	}

	// MARK: - Dock Badge
	@objc func updateDockBadge() {
		let label = unreadCount > 0 ? "\(unreadCount)" : ""
		NSApplication.shared.dockTile.badgeLabel = label
	}

	// MARK: - Actions
	@IBAction func showPreferences(_ sender: Any?) {
		if preferencesWindowController == nil {
			preferencesWindowController = windowControllerWithName("Preferences")
		}

		preferencesWindowController!.showWindow(self)
	}

	@IBAction func newMainWindow(_ sender: Any?) {
		createAndShowMainWindow()
	}

	@IBAction func showMainWindow(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
		mainWindowController?.window?.makeKey()
	}

	@IBAction func refreshAll(_ sender: Any?) {
		AccountManager.shared.refreshAll(errorHandler: ErrorHandler.present)
	}

	@IBAction func showAddWebFeedWindow(_ sender: Any?) {
		addWebFeed(nil)
	}

	@IBAction func showAddRedditFeedWindow(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
		addFeedController = AddFeedController(hostWindow: mainWindowController!.window!)
		addFeedController?.showAddFeedSheet(.redditFeed)
	}

	@IBAction func showAddTwitterFeedWindow(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
		addFeedController = AddFeedController(hostWindow: mainWindowController!.window!)
		addFeedController?.showAddFeedSheet(.twitterFeed)
	}

	@IBAction func showAddFolderWindow(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
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
		createAndShowMainWindowIfNecessary()
		if mainWindowController!.isDisplayingSheet {
			return
		}
		
		importOPMLController = ImportOPMLWindowController()
		importOPMLController?.runSheetOnWindow(mainWindowController!.window!)
	}
	
	@IBAction func importNNW3FromFile(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
		if mainWindowController!.isDisplayingSheet {
			return
		}
		NNW3ImportController.askUserToImportNNW3Subscriptions(window: mainWindowController!.window!)
	}
	
	@IBAction func exportOPML(_ sender: Any?) {
		createAndShowMainWindowIfNecessary()
		if mainWindowController!.isDisplayingSheet {
			return
		}
		
		exportOPMLController = ExportOPMLWindowController()
		exportOPMLController?.runSheetOnWindow(mainWindowController!.window!)
	}
	
	@IBAction func addAppNews(_ sender: Any?) {
		if AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() {
			return
		}
		addWebFeed(AccountManager.netNewsWireNewsURL, name: "NetNewsWire News")
	}

	@IBAction func openWebsite(_ sender: Any?) {

		Browser.open("https://netnewswire.com/", inBackground: false)
	}
	
	@IBAction func openReleaseNotes(_ sender: Any?) {
		Browser.open(URL.releaseNotes.absoluteString, inBackground: false)
	}
	

	@IBAction func openHowToSupport(_ sender: Any?) {
		
		Browser.open("https://github.com/brentsimmons/NetNewsWire/blob/main/Technotes/HowToSupportNetNewsWire.markdown", inBackground: false)
	}
	
	@IBAction func openRepository(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire", inBackground: false)
	}

	@IBAction func openBugTracker(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire/issues", inBackground: false)
	}

	@IBAction func openSlackGroup(_ sender: Any?) {
		Browser.open("https://netnewswire.com/slack", inBackground: false)
	}

	@IBAction func openTechnotes(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/NetNewsWire/tree/main/Technotes", inBackground: false)
	}

	@IBAction func showHelp(_ sender: Any?) {

		Browser.open("https://netnewswire.com/help/mac/6.1/en/", inBackground: false)
	}

	@IBAction func donateToAppCampForGirls(_ sender: Any?) {
		Browser.open("https://appcamp4girls.com/contribute/", inBackground: false)
	}

	@IBAction func showPrivacyPolicy(_ sender: Any?) {
		Browser.open("https://netnewswire.com/privacypolicy", inBackground: false)
	}

	@IBAction func gotoToday(_ sender: Any?) {

		createAndShowMainWindowIfNecessary()
		mainWindowController!.gotoToday(sender)
	}

	@IBAction func gotoAllUnread(_ sender: Any?) {

		createAndShowMainWindowIfNecessary()
		mainWindowController!.gotoAllUnread(sender)
	}

	@IBAction func gotoStarred(_ sender: Any?) {

		createAndShowMainWindowIfNecessary()
		mainWindowController!.gotoStarred(sender)
	}

	@IBAction func sortByOldestArticleOnTop(_ sender: Any?) {

		AppDefaults.shared.timelineSortDirection = .orderedAscending
	}

	@IBAction func sortByNewestArticleOnTop(_ sender: Any?) {

		AppDefaults.shared.timelineSortDirection = .orderedDescending
	}
	
	@IBAction func groupByFeedToggled(_ sender: NSMenuItem) {		
		AppDefaults.shared.timelineGroupByFeed.toggle()
	}

	@IBAction func checkForUpdates(_ sender: Any?) {
		#if !MAC_APP_STORE && !TEST
			self.softwareUpdater.checkForUpdates()
		#endif
	}

}

// MARK: - Debug Menu
extension AppDelegate {

	@IBAction func debugSearch(_ sender: Any?) {
		AccountManager.shared.defaultAccount.debugRunSearch()
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
		CrashReporter.sendCrashLogText("This is a test. Hi, Brent.")
	}

	@IBAction func forceCrash(_ sender: Any?) {
		fatalError("This is a deliberate crash.")
	}

	@IBAction func openApplicationSupportFolder(_ sender: Any?) {
		#if DEBUG
			guard let appSupport = Platform.dataSubfolder(forApplication: nil, folderName: "") else { return }
			NSWorkspace.shared.open(URL(fileURLWithPath: appSupport))
		#endif
	}

	@IBAction func toggleWebInspectorEnabled(_ sender: Any?) {
		#if !MAC_APP_STORE
		let newValue = !AppDefaults.shared.webInspectorEnabled
		AppDefaults.shared.webInspectorEnabled = newValue

			// An attached inspector can display incorrectly on certain setups (like mine); default to displaying in a separate window,
			// and reset the default to a separate window when the preference is toggled off and on again in case the inspector is
			// accidentally reattached.
		AppDefaults.shared.webInspectorStartsAttached = false
			NotificationCenter.default.post(name: .WebInspectorEnabledDidChange, object: newValue)
		#endif
	}

}

internal extension AppDelegate {

	func fireOldTimers() {
		// It’s possible there’s a refresh timer set to go off in the past.
		// In that case, refresh now and update the timer.
		refreshTimer?.fireOldTimer()
		syncTimer?.fireOldTimer()
	}
	
	func objectsForInspector() -> [Any]? {
		guard let window = NSApplication.shared.mainWindow, let windowController = window.windowController as? MainWindowController else {
			return nil
		}
		return windowController.selectedObjectsInSidebar()
	}

	func saveState() {
		mainWindowController?.saveStateToUserDefaults()
		inspectorWindowController?.saveState()
	}

	func updateSortMenuItems() {
		let sortByNewestOnTop = AppDefaults.shared.timelineSortDirection == .orderedDescending
		sortByNewestArticleOnTopMenuItem.state = sortByNewestOnTop ? .on : .off
		sortByOldestArticleOnTopMenuItem.state = sortByNewestOnTop ? .off : .on
	}
	
	func updateGroupByFeedMenuItem() {
		let groupByFeedEnabled = AppDefaults.shared.timelineGroupByFeed
		groupArticlesByFeedMenuItem.state = groupByFeedEnabled ? .on : .off
	}
	
	func importTheme(filename: String) {
		guard let window = mainWindowController?.window else { return }
		
		do {
			let theme = try ArticleTheme(path: filename, isAppTheme: false)
			let alert = NSAlert()
			alert.alertStyle = .informational

			let localizedMessageText = NSLocalizedString("Install theme “%@” by %@?", comment: "Theme message text")
			alert.messageText = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.name, theme.creatorName) as String
			
			var attrs = [NSAttributedString.Key : Any]()
			attrs[.font] = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
			attrs[.foregroundColor] = NSColor.textColor
			
			let titleParagraphStyle = NSMutableParagraphStyle()
			titleParagraphStyle.alignment = .center
			attrs[.paragraphStyle] = titleParagraphStyle

			let websiteText = NSMutableAttributedString()
			websiteText.append(NSAttributedString(string: NSLocalizedString("Author‘s website:", comment: "Author's Website"), attributes: attrs))

			websiteText.append(NSAttributedString(string: "\n"))

			attrs[.link] = theme.creatorHomePage
			websiteText.append(NSAttributedString(string: theme.creatorHomePage, attributes: attrs))

			let textViewWidth: CGFloat
			textViewWidth = 200

			let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: textViewWidth, height: 15))
			textView.isEditable = false
			textView.drawsBackground = false
			textView.textStorage?.setAttributedString(websiteText)
			alert.accessoryView = textView
			
			alert.addButton(withTitle: NSLocalizedString("Install Theme", comment: "Install Theme"))
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Install Theme"))
				
			func importTheme() {
				do {
					try ArticleThemesManager.shared.importTheme(filename: filename)
					confirmImportSuccess(themeName: theme.name)
				} catch {
					NSApplication.shared.presentError(error)
				}
			}
			
			alert.beginSheetModal(for: window) { result in
				if result == NSApplication.ModalResponse.alertFirstButtonReturn {

					if ArticleThemesManager.shared.themeExists(filename: filename) {
						let alert = NSAlert()
						alert.alertStyle = .warning

						let localizedMessageText = NSLocalizedString("The theme “%@” already exists. Overwrite it?", comment: "Overwrite theme")
						alert.messageText = NSString.localizedStringWithFormat(localizedMessageText as NSString, theme.name) as String

						alert.addButton(withTitle: NSLocalizedString("Overwrite", comment: "Overwrite"))
						alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Install Theme"))
						
						alert.beginSheetModal(for: window) { result in
							if result == NSApplication.ModalResponse.alertFirstButtonReturn {
								importTheme()
							}
						}
					} else {
						importTheme()
					}
				}
			}
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error" : error, "path": filename])
		}
	}
	
	func confirmImportSuccess(themeName: String) {
		guard let window = mainWindowController?.window else { return }
		
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Theme installed", comment: "Theme installed")
		
		let localizedInformativeText = NSLocalizedString("The theme “%@” has been installed.", comment: "Theme installed")
		alert.informativeText = NSString.localizedStringWithFormat(localizedInformativeText as NSString, themeName) as String
		
		alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK"))

		alert.beginSheetModal(for: window)
	}
	
	@objc func themeImportError(_ note: Notification) {
		guard let userInfo = note.userInfo,
			  let error = userInfo["error"] as? Error else {
				  return
			  }
		themeImportPath = userInfo["path"] as? String
		var informativeText: String = ""
		if let decodingError = error as? DecodingError {
			switch decodingError {
			case .typeMismatch(let type, _):
				let localizedError = NSLocalizedString("This theme cannot be used because the the type—“%@”—is mismatched in the Info.plist", comment: "Type mismatch")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, type as! CVarArg) as String
			case .valueNotFound(let value, _):
				let localizedError = NSLocalizedString("This theme cannot be used because the the value—“%@”—is not found in the Info.plist.", comment: "Decoding value missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, value as! CVarArg) as String
			case .keyNotFound(let codingKey, _):
				let localizedError = NSLocalizedString("This theme cannot be used because the the key—“%@”—is not found in the Info.plist.", comment: "Decoding key missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, codingKey.stringValue) as String
			case .dataCorrupted(let context):
				guard let underlyingError = context.underlyingError as NSError?,
					  let debugDescription = underlyingError.userInfo["NSDebugDescription"] as? String else {
					informativeText = error.localizedDescription
					break
				}
				let localizedError = NSLocalizedString("This theme cannot be used because of data corruption in the Info.plist: %@.", comment: "Decoding key missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, debugDescription) as String
				
			default:
				informativeText = error.localizedDescription
			}
		} else {
			informativeText = error.localizedDescription
		}
		
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.alertStyle = .warning
			alert.messageText = NSLocalizedString("Theme Error", comment: "Theme download error")
			alert.informativeText = informativeText
			alert.addButton(withTitle: NSLocalizedString("Open Theme Folder", comment: "Open Theme Folder"))
			alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK"))
			
			let button = alert.buttons.first
			button?.target = self
			button?.action = #selector(self.openThemesFolder(_:))
			alert.buttons[0].keyEquivalent = "\033"
			alert.buttons[1].keyEquivalent = "\r"
			alert.runModal()
		}
	}
	
	@objc func openThemesFolder(_ sender: Any) {
		if themeImportPath == nil {
			let url = URL(fileURLWithPath: ArticleThemesManager.shared.folderPath)
			NSWorkspace.shared.open(url)
		} else {
			let url = URL(fileURLWithPath: themeImportPath!)
			NSWorkspace.shared.open(url.deletingLastPathComponent())
		}
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

extension AppDelegate: NSWindowRestoration {
	
	@objc static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
		var mainWindow: NSWindow? = nil
		if identifier.rawValue == WindowRestorationIdentifiers.mainWindow {
			mainWindow = appDelegate.createAndShowMainWindow().window
		}
		completionHandler(mainWindow, nil)
	}
	
}

// Handle Notification Actions

private extension AppDelegate {
	
	func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}
		
		let account = AccountManager.shared.existingAccount(with: accountID)
		guard account != nil else {
			os_log(.debug, "No account found from notification.")
			return
		}
		let article = try? account!.fetchArticles(.articleIDs([articleID]))
		guard article != nil else {
			os_log(.debug, "No article found from search using %@", articleID)
			return
		}
		account!.markArticles(article!, statusKey: .read, flag: true) { _ in }
	}
	
	func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}
		let account = AccountManager.shared.existingAccount(with: accountID)
		guard account != nil else {
			os_log(.debug, "No account found from notification.")
			return
		}
		let article = try? account!.fetchArticles(.articleIDs([articleID]))
		guard article != nil else {
			os_log(.debug, "No article found from search using %@", articleID)
			return
		}
		account!.markArticles(article!, statusKey: .starred, flag: true) { _ in }
	}
}
