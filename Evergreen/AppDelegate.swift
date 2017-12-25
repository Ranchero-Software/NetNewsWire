//
//  AppDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/11/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
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
	private var mainWindowController: NSWindowController?
	private var readerWindows = [NSWindowController]()
	private var feedListWindowController: NSWindowController?
	private var addFeedController: AddFeedController?
	private var addFolderWindowController: AddFolderWindowController?
	private var keyboardShortcutsWindowController: WebViewWindowController?
	private var inspectorWindowController: InspectorWindowController?
	private var logWindowController: LogWindowController?
	private var panicButtonWindowController: PanicButtonWindowController?
	
	private let log = Log()
	private let themeLoader = VSThemeLoader()
	private let appNewsURLString = "https://ranchero.com/evergreen/feed.json"
	private let dockBadge = DockBadge()

	override init() {

		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()
		dockBadge.appDelegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
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

	func markOlderArticlesAsRead(with window: NSWindow) {

		panicButtonWindowController = PanicButtonWindowController()
		panicButtonWindowController!.runSheetOnWindow(window)
	}

	func markEverywhereAsRead(with window: NSWindow) {

		let alert = NSAlert()
		alert.messageText = NSLocalizedString("Mark All Articles as Read Everywhere?", comment: "Mark Everywhere alert messageText")
		alert.informativeText = NSLocalizedString("This will mark every single article as read. All of them. The unread count will be zero.\n\nNote: this operation cannot be undone.", comment: "Mark Everywhere informativeText.")

		alert.addButton(withTitle: NSLocalizedString("Mark All Articles as Read", comment: "Mark Everywhere alert button."))
		alert.addButton(withTitle: NSLocalizedString("Don’t Mark as Read", comment: "Mark Everywhere alert button."))

		alert.beginSheetModal(for: window) { (returnCode) in

			if returnCode == .alertFirstButtonReturn {
				self.markEverywhereAsRead()
			}
		}
	}

	func markEverywhereAsRead() {

		AccountManager.shared.accounts.forEach { $0.markEverywhereAsRead() }
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

		createAndShowMainWindow()

		NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.getURL(_:_:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))

		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		#if RELEASE
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

		if item.action == #selector(refreshAll(_:)) {
			return !AccountManager.shared.refreshInProgress
		}
		if item.action == #selector(addAppNews(_:)) {
			return !AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString)
		}
		return true
	}

	// MARK: Add Feed

	func addFeed(_ urlString: String?, _ name: String? = nil) {

		createAndShowMainWindow()

		addFeedController = AddFeedController(hostWindow: mainWindowController!.window!)
		addFeedController?.showAddFeedSheet(urlString, name)
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
			inspectorWindowController = InspectorWindowController()
		}

		if inspectorWindowController!.isOpen {
			inspectorWindowController!.window!.performClose(self)
		}
		else {
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

	@IBAction func markOlderArticlesAsRead(_ sender: Any?) {

		createAndShowMainWindow()
		markOlderArticlesAsRead(with: mainWindowController!.window!)
	}

	@IBAction func markEverywhereAsRead(_ sender: Any?) {

		createAndShowMainWindow()
		markEverywhereAsRead(with: mainWindowController!.window!)
	}

	@IBAction func debugDropConditionalGetInfo(_ sender: Any?) {
		#if DEBUG
			AccountManager.shared.accounts.forEach{ $0.debugDropConditionalGetInfo() }
		#endif
	}
}

private extension AppDelegate {

	func createReaderWindow() -> NSWindowController {

		return windowControllerWithName("MainWindow")
	}
}
