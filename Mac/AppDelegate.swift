//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/11/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import UserNotifications
import os
import Articles
import Account
import RSCore
import RSCoreResources
import RSWeb
import Secrets
import CrashReporter
import Sparkle

let appName = "NetNewsWire"

var appDelegate: AppDelegate!

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations, UNUserNotificationCenterDelegate, UnreadCountProvider, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

	private struct WindowRestorationIdentifiers {
		static let mainWindow = "mainWindow"
	}

	private var refreshTimer: AccountRefreshTimer?
	private var lastRefreshInterval = AppDefaults.shared.refreshInterval

	private var shuttingDown = false {
		didSet {
			if shuttingDown {
				refreshTimer?.shuttingDown = shuttingDown
				refreshTimer?.invalidate()
				ArticleStatusSyncTimer.shared.stop()
			}
		}
	}

	private var isShutDownSyncDone = false

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
	private lazy var preferencesWindowController = windowControllerWithName("Preferences")
	private var addFeedController: AddFeedController?
	private var addFolderWindowController: AddFolderWindowController?
	private var importOPMLController: ImportOPMLWindowController?
	private var exportOPMLController: ExportOPMLWindowController?
	private var keyboardShortcutsWindowController: WebViewWindowController?
	private var inspectorWindowController: InspectorWindowController?
	private var crashReportWindowController: CrashReportWindowController? // For testing only
	private let appMovementMonitor = RSAppMovementMonitor()
	private var softwareUpdater: SPUUpdater!
	private var crashReporter: PLCrashReporter!

	private var themeImportPath: String?

	override init() {
		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()

		appDelegate = self
		let crashReporterConfig = PLCrashReporterConfig.defaultConfiguration()
		crashReporter = PLCrashReporter(configuration: crashReporterConfig)
		crashReporter.enable()

		SecretsManager.provider = Secrets()
		AccountManager.shared.start()
		ArticleThemesManager.shared = ArticleThemesManager(folderPath: Platform.dataSubfolder(forApplication: nil, folderName: "Themes")!)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(inspectableObjectsDidChange(_:)), name: .InspectableObjectsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(importDownloadedTheme(_:)), name: .didEndDownloadingTheme, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(themeImportError(_:)), name: .didFailToImportThemeWithError, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWakeNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)
	}

	// MARK: - API
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

		let imagesFolder = (cacheFolder as NSString).appendingPathComponent("Images")
		let imagesFolderURL = URL(fileURLWithPath: imagesFolder)
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
	}

	func applicationDidFinishLaunching(_ note: Notification) {

		// Initialize Sparkle...
		let hostBundle = Bundle.main
		let updateDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: self)
		self.softwareUpdater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: updateDriver, delegate: self)

		do {
			try self.softwareUpdater.start()
		}
		catch {
			Self.logger.error("Failed to start software updater with error: \(error.localizedDescription)")
		}

		AppDefaults.shared.registerDefaults()
		let isFirstRun = AppDefaults.shared.isFirstRun
		if isFirstRun {
			Self.logger.debug("Is first run.")
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

		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		if InspectorWindowController.shouldOpenAtStartup {
			self.toggleInspectorWindow(self)
		}

		NetworkMonitor.shared.start()
		ExtensionContainersFile.shared.start()
		ExtensionFeedAddRequestFile.shared.start()

		refreshTimer = AccountRefreshTimer()
		ArticleStatusSyncTimer.shared.start()

		UNUserNotificationCenter.current().requestAuthorization(options:[.badge]) { (granted, error) in }

		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		UserNotificationManager.shared.start()

		#if DEBUG
		refreshTimer!.update()
		ArticleStatusSyncTimer.shared.update()
		#else
		if AppDefaults.shared.suppressSyncOnLaunch {
			refreshTimer!.update()
			ArticleStatusSyncTimer.shared.update.update()
		} else {
			DispatchQueue.main.async {
				self.refreshTimer!.timedRefresh(nil)
				ArticleStatusSyncTimer.shared.timedRefresh(nil)
			}
		}
		#endif

		if !AppDefaults.shared.showDebugMenu {
			debugMenuItem.menu?.removeItem(debugMenuItem)
		}

		DispatchQueue.main.async {
			CrashReporter.check(crashReporter: self.crashReporter)
		}
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

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
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
		guard filename.hasSuffix(ArticleTheme.nnwThemeSuffix) else {
			return false
		}

		let url = URL(filePath: filename)
		importTheme(url: url)
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

	@objc func feedSettingDidChange(_ note: Notification) {
		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.SettingUserInfoKey] as? String else {
			return
		}
		if key == Feed.SettingKey.homePageURL || key == Feed.SettingKey.faviconURL {
			_ = FaviconDownloader.shared.favicon(for: feed)
		}
	}

	@objc func inspectableObjectsDidChange(_ note: Notification) {
		guard let inspectorWindowController = inspectorWindowController, inspectorWindowController.isOpen else {
			return
		}
		inspectorWindowController.objects = objectsForInspector()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		Task { @MainActor in
			updateSortMenuItems()
			updateGroupByFeedMenuItem()

			if lastRefreshInterval != AppDefaults.shared.refreshInterval {
				refreshTimer?.update()
				lastRefreshInterval = AppDefaults.shared.refreshInterval
			}

			updateDockBadge()
		}
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
			self.importTheme(url: url)
		}
	}

	// MARK: Main Window

	func createMainWindowController() -> MainWindowController {
		let controller: MainWindowController = windowControllerWithName("UnifiedWindow") as! MainWindowController

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

		if item.action == #selector(showAddFeedWindow(_:)) || item.action == #selector(showAddFolderWindow(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.activeAccounts.isEmpty
		}

		if item.action == #selector(toggleWebInspectorEnabled(_:)) {
			(item as! NSMenuItem).state = AppDefaults.shared.webInspectorEnabled ? .on : .off
		}

		return true
	}

	// MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

		let userInfo = response.notification.request.content.userInfo

		switch response.actionIdentifier {
		case UserNotificationManager.ActionIdentifier.markAsRead:
			handleMarkAsRead(userInfo: userInfo)
		case UserNotificationManager.ActionIdentifier.markAsStarred:
			handleMarkAsStarred(userInfo: userInfo)
		default:
			mainWindowController?.handle(response)
		}
		completionHandler()
    }

	// MARK: Add Feed
	func addFeed(_ urlString: String?, name: String? = nil, account: Account? = nil, folder: Folder? = nil) {
		createAndShowMainWindowIfNecessary()

		if mainWindowController!.isDisplayingSheet {
			return
		}

		showAddFeedSheetOnWindow(mainWindowController!.window!, urlString: urlString, name: name, account: account, folder: folder)
	}

	// MARK: - Dock Badge
	@objc func updateDockBadge() {
		Task { @MainActor in
			let label = unreadCount > 0 ? "\(unreadCount)" : ""
			NSApplication.shared.dockTile.badgeLabel = label
		}
	}

	// MARK: - Actions
	@IBAction func showPreferences(_ sender: Any?) {
		preferencesWindowController.showWindow(self)
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

	@IBAction func showAddFeedWindow(_ sender: Any?) {
		addFeed(nil)
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
		addFeed(AccountManager.netNewsWireNewsURL, name: "NetNewsWire News")
	}

	@IBAction func openWebsite(_ sender: Any?) {
		HelpURL.website.open()
	}

	@IBAction func openReleaseNotes(_ sender: Any?) {
		HelpURL.releaseNotes.open()
	}

	@IBAction func openHowToSupport(_ sender: Any?) {
		HelpURL.howToSupportNetNewsWire.open()
	}

	@IBAction func openTechnotes(_ sender: Any?) {
		HelpURL.technotes.open()
	}

	@IBAction func openRepository(_ sender: Any?) {
		HelpURL.githubRepo.open()
	}

	@IBAction func openBugTracker(_ sender: Any?) {
		HelpURL.bugTracker.open()
	}

	@IBAction func openSlackGroup(_ sender: Any?) {
		HelpURL.slack.open()
	}

	@IBAction func showHelp(_ sender: Any?) {
		HelpURL.helpHome.open()
	}

	@IBAction func showPrivacyPolicy(_ sender: Any?) {
		HelpURL.privacyPolicy.open()
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

	@IBAction func showCustomAboutPanel(_ sender: Any?) {
		let aboutWC = AboutWindowController(windowNibName: "AboutWindowController")
		aboutWC.showWindow(nil)
		aboutWC.window?.center()
		aboutWC.window?.makeKeyAndOrderFront(nil)
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
		softwareUpdater.checkForUpdates()
	}
}

// MARK: - Debug Menu
extension AppDelegate {

	@IBAction func debugSearch(_ sender: Any?) {
		AccountManager.shared.defaultAccount.debugRunSearch()
	}

	@IBAction func debugDropConditionalGetInfo(_ sender: Any?) {
#if DEBUG
		for account in AccountManager.shared.activeAccounts {
			account.debugDropConditionalGetInfo()
		}
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
		guard let appSupport = Platform.dataSubfolder(forApplication: nil, folderName: "") else {
			assertionFailure("Expected non-nil app support folder path")
			return
		}

		NSWorkspace.shared.open(URL(fileURLWithPath: appSupport))
	}

	@IBAction func toggleWebInspectorEnabled(_ sender: Any?) {
		let newValue = !AppDefaults.shared.webInspectorEnabled
		AppDefaults.shared.webInspectorEnabled = newValue

			// An attached inspector can display incorrectly on certain setups (like mine); default to displaying in a separate window,
			// and reset the default to a separate window when the preference is toggled off and on again in case the inspector is
			// accidentally reattached.
		AppDefaults.shared.webInspectorStartsAttached = false
			NotificationCenter.default.post(name: .WebInspectorEnabledDidChange, object: newValue)
	}

	@IBAction func showiCloudDriveMissingAlert(_ sender: Any?) {
		// Manual testing for alert in AccountsAddCloudKitWindowController
		// Check for:
		// - Expected text
		// - Button for opening Settings
		// - Button works
		mainWindowController?.presentError(AddCloudKitAccountError.iCloudDriveMissing)
	}
}

internal extension AppDelegate {

	func fireOldTimers() {
		// It’s possible there’s a refresh timer set to go off in the past.
		// In that case, refresh now and update the timer.
		refreshTimer?.fireOldTimer()
		ArticleStatusSyncTimer.shared.fireOldTimer()
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

	@MainActor func updateSortMenuItems() {
		let sortByNewestOnTop = AppDefaults.shared.timelineSortDirection == .orderedDescending
		sortByNewestArticleOnTopMenuItem.state = sortByNewestOnTop ? .on : .off
		sortByOldestArticleOnTopMenuItem.state = sortByNewestOnTop ? .off : .on
	}

	@MainActor func updateGroupByFeedMenuItem() {
		let groupByFeedEnabled = AppDefaults.shared.timelineGroupByFeed
		groupArticlesByFeedMenuItem.state = groupByFeedEnabled ? .on : .off
	}

	func importTheme(url: URL) {
		guard let window = mainWindowController?.window else { return }

		do {
			let theme = try ArticleTheme(url: url, isAppTheme: false)
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
					try ArticleThemesManager.shared.importTheme(filename: url.path)
					confirmImportSuccess(themeName: theme.name)
				} catch {
					NSApplication.shared.presentError(error)
				}
			}

			alert.beginSheetModal(for: window) { result in
				if result == NSApplication.ModalResponse.alertFirstButtonReturn {

					if ArticleThemesManager.shared.themeExists(filename: url.path) {
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
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error" : error, "path": url.path])
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
		handleStatusNotification(userInfo: userInfo, statusKey: .read)
	}

	func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
		handleStatusNotification(userInfo: userInfo, statusKey: .starred)
	}

	private func handleStatusNotification(userInfo: [AnyHashable: Any], statusKey: ArticleStatus.Key) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable : Any],
			  let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			  let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
			assertionFailure("Expected valid articlePathUserInfo from userInfo \(userInfo)")
			Self.logger.error("No valid articlePathUserInfo from userInfo \(userInfo) in status notification")
			return
		}

		guard let account = AccountManager.shared.existingAccount(with: accountID) else {
			assertionFailure("Expected account with \(accountID)")
			Self.logger.error("No account with accountID \(accountID) found from status notification")
			return
		}

		guard let singleArticleSet = try? account.fetchArticles(.articleIDs([articleID])) else {
			assertionFailure("Expected article with \(articleID)")
			Self.logger.error("No article with articleID found \(articleID) from status notification")
			return
		}

		assert(singleArticleSet.count == 1)
		account.markArticles(singleArticleSet, statusKey: statusKey, flag: true) { _ in }
	}
}
