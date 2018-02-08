//
//  AppDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/11/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import DB5
import Data
import RSTextDrawing
import RSTree
import RSWeb
import Account
import RSCore

var appDelegate: AppDelegate!

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations, UnreadCountProvider {

	var currentTheme: VSTheme!
	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var feedIconDownloader: FeedIconDownloader!
	var appName: String!

	@IBOutlet var debugMenuItem: NSMenuItem!
	@IBOutlet var sortByOldestArticleOnTopMenuItem: NSMenuItem!
	@IBOutlet var sortByNewestArticleOnTopMenuItem: NSMenuItem!

	lazy var genericFeedImage: NSImage? = {
		let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/BookmarkIcon.icns"
		let image = NSImage(contentsOfFile: path)
		return image
	}()

	lazy var sendToCommands: [SendToCommand] = {
		return [SendToMicroBlogCommand(), SendToMarsEditCommand()]
	}()

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				dockBadge.update()
				postUnreadCountDidChangeNotification()
			}
		}
	}

	private let windowControllers = NSMutableArray()
	private var preferencesWindowController: NSWindowController?
	private var mainWindowController: MainWindowController?
	private var readerWindows = [NSWindowController]()
	private var feedListWindowController: NSWindowController?
	private var addFeedController: AddFeedController?
	private var addFolderWindowController: AddFolderWindowController?
	private var keyboardShortcutsWindowController: WebViewWindowController?
	private var inspectorWindowController: InspectorWindowController?
	private var logWindowController: LogWindowController?

	private let log = Log()
	private let themeLoader = VSThemeLoader()
	private let appNewsURLString = "https://ranchero.com/evergreen/feed.json"
	private let dockBadge = DockBadge()

	override init() {

		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()
		dockBadge.appDelegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(sidebarSelectionDidChange(_:)), name: .SidebarSelectionDidChange, object: nil)

		appDelegate = self
	}

	// MARK: - API

	func logMessage(_ message: String, type: LogItem.ItemType) {

		#if DEBUG
			print("logMessage: \(message) - \(type)")
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

	func showAddFeedSheetOnWindow(_ window: NSWindow, urlString: String?, name: String?) {

		addFeedController = AddFeedController(hostWindow: window)
		addFeedController?.showAddFeedSheet(urlString, name)
	}

	// MARK: - NSApplicationDelegate

	func applicationDidFinishLaunching(_ note: Notification) {

		appName = Bundle.main.infoDictionary!["CFBundleExecutable"]! as! String

		let isFirstRun = AppDefaults.shared.isFirstRun
		if isFirstRun {
			logDebugMessage("Is first run.")
		}
		let localAccount = AccountManager.shared.localAccount
		DefaultFeedsImporter.importIfNeeded(isFirstRun, account: localAccount)

		currentTheme = themeLoader.defaultTheme

		let tempDirectory = NSTemporaryDirectory()
		let cacheFolder = (tempDirectory as NSString).appendingPathComponent("com.ranchero.evergreen")

		let faviconsFolder = (cacheFolder as NSString).appendingPathComponent("Favicons")
		let faviconsFolderURL = URL(fileURLWithPath: faviconsFolder)
		try! FileManager.default.createDirectory(at: faviconsFolderURL, withIntermediateDirectories: true, attributes: nil)
		faviconDownloader = FaviconDownloader(folder: faviconsFolder)

		let imagesFolder = (cacheFolder as NSString).appendingPathComponent("Images")
		let imagesFolderURL = URL(fileURLWithPath: imagesFolder)
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
		imageDownloader = ImageDownloader(folder: imagesFolder)

		authorAvatarDownloader = AuthorAvatarDownloader(imageDownloader: imageDownloader)
		feedIconDownloader = FeedIconDownloader(imageDownloader: imageDownloader)

		updateSortMenuItems()
		createAndShowMainWindow()

		NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.getURL(_:_:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		if InspectorWindowController.shouldOpenAtStartup {
			self.toggleInspectorWindow(self)
		}

		#if RELEASE
			debugMenuItem.menu?.removeItem(debugMenuItem)
			DispatchQueue.main.async {
				self.refreshAll(self)
			}
		#endif
	}

	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {

		if (!flag) {
			createAndShowMainWindow()
		}
		return false
	}

	func applicationDidResignActive(_ notification: Notification) {

		RSSingleLineRenderer.emptyCache()
		RSMultiLineRenderer.emptyCache()
		TimelineCellData.emptyCache()
		timelineEmptyCaches()

		saveState()
	}

	func applicationWillTerminate(_ notification: Notification) {

		saveState()
	}

	// MARK: GetURL Apple Event

	@objc func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor) {

		guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
			return
		}

		let normalizedURLString = urlString.rs_normalizedURL()
		if !normalizedURLString.rs_stringMayBeURL() {
			return
		}

		DispatchQueue.main.async {

			self.addFeed(normalizedURLString)
		}
	}

	// MARK: Notifications

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	@objc func feedSettingDidChange(_ note: Notification) {

		guard let feed = note.object as? Feed else {
			return
		}
		let _ = faviconDownloader.favicon(for: feed)
	}

	@objc func sidebarSelectionDidChange(_ note: Notification) {

		guard let inspectorWindowController = inspectorWindowController, inspectorWindowController.isOpen else {
			return
		}
		inspectorWindowController.objects = objectsForInspector()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {

		updateSortMenuItems()
	}

	// MARK: Main Window

	func windowControllerWithName(_ storyboardName: String) -> NSWindowController {

		let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: storyboardName), bundle: nil)
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

		let isDisplayingSheet = mainWindowController?.isDisplayingSheet ?? false

		if item.action == #selector(refreshAll(_:)) {
			return !AccountManager.shared.refreshInProgress
		}
		if item.action == #selector(addAppNews(_:)) {
			return !isDisplayingSheet && !AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString)
		}
		if item.action == #selector(sortByNewestArticleOnTop(_:)) || item.action == #selector(sortByOldestArticleOnTop(_:)) {
			return mainWindowController?.isOpen ?? false
		}
		if item.action == #selector(showAddFeedWindow(_:)) || item.action == #selector(showAddFolderWindow(_:)) {
			return !isDisplayingSheet
		}
		return true
	}

	// MARK: Add Feed

	func addFeed(_ urlString: String?, _ name: String? = nil) {

		createAndShowMainWindow()
		if mainWindowController!.isDisplayingSheet {
			return
		}

		showAddFeedSheetOnWindow(mainWindowController!.window!, urlString: urlString, name: name)
	}

	// MARK: - Actions

	@IBAction func newReaderWindow(_ sender: Any?) {

		let readerWindow = createReaderWindow()
		readerWindows += [readerWindow]
		readerWindow.showWindow(self)
	}

	@IBAction func showPreferences(_ sender: AnyObject) {

		if preferencesWindowController == nil {
			preferencesWindowController = windowControllerWithName("Preferences")
		}

		preferencesWindowController!.showWindow(self)
	}

	@IBAction func showMainWindow(_ sender: AnyObject) {

		createAndShowMainWindow()
	}

	@IBAction func refreshAll(_ sender: AnyObject) {

		AccountManager.shared.refreshAll()
	}

	@IBAction func showAddFeedWindow(_ sender: AnyObject) {

		addFeed(nil)
	}

	@IBAction func showAddFolderWindow(_ sender: AnyObject) {

		createAndShowMainWindow()
		showAddFolderSheetOnWindow(mainWindowController!.window!)
	}

	@IBAction func showFeedList(_ sender: AnyObject) {

		if feedListWindowController == nil {
			feedListWindowController = windowControllerWithName("FeedList")
		}
		feedListWindowController!.showWindow(self)
	}

	@IBAction func showKeyboardShortcutsWindow(_ sender: Any?) {

		if keyboardShortcutsWindowController == nil {
			keyboardShortcutsWindowController = WebViewWindowController(title: NSLocalizedString("Keyboard Shortcuts", comment: "window title"))
			let htmlFile = Bundle(for: type(of: self)).path(forResource: "KeyboardShortcuts", ofType: "html")!
			keyboardShortcutsWindowController?.displayContents(of: htmlFile)

			if let window = keyboardShortcutsWindowController?.window {
				let point = NSPoint(x: 128, y: 64)
				let size = NSSize(width: 620, height: 1000)
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

	@IBAction func showLogWindow(_ sender: Any?) {

		if logWindowController == nil {
			logWindowController = LogWindowController(title: "Errors", log: log)
		}

		logWindowController!.showWindow(self)
	}
	
	@IBAction func importOPMLFromFile(_ sender: AnyObject) {

		let panel = NSOpenPanel()
		panel.canDownloadUbiquitousContents = true
		panel.canResolveUbiquitousConflicts = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.resolvesAliases = true
		panel.allowedFileTypes = ["opml"]
		panel.allowsOtherFileTypes = false

		let result = panel.runModal()
		if result == NSApplication.ModalResponse.OK, let url = panel.url {
			DispatchQueue.main.async {
				do {
					try OPMLImporter.parseAndImport(fileURL: url, account: AccountManager.shared.localAccount)
				}
				catch let error as NSError {
					NSApplication.shared.presentError(error)
				}
			}
		}
	}
	
	@IBAction func importOPMLFromURL(_ sender: AnyObject) {

	}

	@IBAction func exportOPML(_ sender: AnyObject) {

		let panel = NSSavePanel()
		panel.allowedFileTypes = ["opml"]
		panel.allowsOtherFileTypes = false
		panel.prompt = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.title = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.nameFieldLabel = NSLocalizedString("Export to:", comment: "Export OPML")
		panel.message = NSLocalizedString("Choose a location for the exported OPML file.", comment: "Export OPML")
		panel.isExtensionHidden = false
		panel.nameFieldStringValue = "MySubscriptions.opml"

		let result = panel.runModal()
		if result == NSApplication.ModalResponse.OK, let url = panel.url {
			DispatchQueue.main.async {
				let filename = url.lastPathComponent
				let opmlString = OPMLExporter.OPMLString(with: AccountManager.shared.localAccount, title: filename)
				do {
					try opmlString.write(to: url, atomically: true, encoding: String.Encoding.utf8)
				}
				catch let error as NSError {
					NSApplication.shared.presentError(error)
				}
			}
		}
	}
	
	@IBAction func addAppNews(_ sender: AnyObject) {

		if AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) {
			return
		}
		addFeed(appNewsURLString, "Evergreen News")
	}

	@IBAction func openWebsite(_ sender: AnyObject) {

		Browser.open("https://ranchero.com/evergreen/", inBackground: false)
	}

	@IBAction func openRepository(_ sender: AnyObject) {

		Browser.open("https://github.com/brentsimmons/Evergreen", inBackground: false)
	}

	@IBAction func openBugTracker(_ sender: AnyObject) {

		Browser.open("https://github.com/brentsimmons/Evergreen/issues", inBackground: false)
	}

	@IBAction func openTechnotes(_ sender: Any?) {

		Browser.open("https://github.com/brentsimmons/Evergreen/tree/master/Technotes", inBackground: false)
	}

	@IBAction func showHelp(_ sender: AnyObject) {

		Browser.open("https://ranchero.com/evergreen/help/1.0/", inBackground: false)
	}

	@IBAction func debugDropConditionalGetInfo(_ sender: Any?) {
		#if DEBUG
			AccountManager.shared.accounts.forEach{ $0.debugDropConditionalGetInfo() }
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

		AppDefaults.shared.timelineSortDirection = .orderedAscending
	}

	@IBAction func sortByNewestArticleOnTop(_ sender: Any?) {

		AppDefaults.shared.timelineSortDirection = .orderedDescending
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

		if let inspectorWindowController = inspectorWindowController {
			inspectorWindowController.saveState()
		}
	}

	func updateSortMenuItems() {

		let sortByNewestOnTop = AppDefaults.shared.timelineSortDirection == .orderedDescending
		sortByNewestArticleOnTopMenuItem.state = sortByNewestOnTop ? .on : .off
		sortByOldestArticleOnTopMenuItem.state = sortByNewestOnTop ? .off : .on
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

