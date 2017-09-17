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
import RSParser
import RSWeb

var currentTheme: VSTheme!

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations {

	let windowControllers = NSMutableArray()
	var preferencesWindowController: NSWindowController?
	var mainWindowController: NSWindowController?
	var feedListWindowController: NSWindowController?
	var addFeedController: AddFeedController?
	var addFolderWindowController: AddFolderWindowController?
	let themeLoader = VSThemeLoader()
	private let appNewsURLString = "https://ranchero.com/evergreen/feed.json"

	var unreadCount = 0 {
		didSet {
			updateBadgeCoalesced()
		}
	}

	override init() {

		NSWindow.allowsAutomaticWindowTabbing = false
		super.init()
	}

	private func evergreenImage() -> NSImage? {
		var image: NSImage? = nil
		let imageWidth = 1024
		let imageHeight = 1024
		let imageSize = NSMakeSize(CGFloat(imageWidth), CGFloat(imageHeight))

		if let drawingContext = CGContext(data: nil, width: imageWidth, height: imageHeight, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {

			let graphicsContext = NSGraphicsContext(cgContext: drawingContext, flipped: false)
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.setCurrent(graphicsContext)

			let targetRect = NSRect(origin: NSZeroPoint, size: imageSize)
			NSString(string: "🌲").draw(in: targetRect, withAttributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 1000)])

			NSGraphicsContext.restoreGraphicsState()

			if let coreImage = drawingContext.makeImage() {
				image = NSImage(cgImage: coreImage, size: imageSize)
			}
		}

		return image
	}

	// MARK: NSApplicationDelegate

	func applicationDidFinishLaunching(_ note: Notification) {

		if let appIconImage = evergreenImage() {
			appIconImage.setName("NSApplicationIcon")
			NSApplication.shared().applicationIconImage = appIconImage
		}

		registerDefaults()

		currentTheme = themeLoader.defaultTheme

		let _ = AccountManager.sharedInstance

		let kFirstRunDateKey = "firstRun"
		var isFirstRun = false
		if UserDefaults.standard.object(forKey: kFirstRunDateKey) == nil {
			isFirstRun = true
			UserDefaults.standard.set(Date(), forKey: kFirstRunDateKey)
		}

		importDefaultFeedsIfNeeded(isFirstRun, account: AccountManager.sharedInstance.localAccount)
		createAndShowMainWindow()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		AccountManager.sharedInstance.updateUnreadCount()

		#if RELEASE
			DispatchQueue.main.async {
				self.refreshAll(self)
			}
		#endif

		NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.getURL(_:_:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
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

	func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor) {

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


	// MARK: Badge

	private func updateBadgeCoalesced() {

		rs_performSelectorCoalesced(#selector(updateBadge), with: nil, afterDelay: 0.01)
	}

	dynamic func updateBadge() {

		let label = unreadCount > 0 ? "\(unreadCount)" : ""
		NSApplication.shared().dockTile.badgeLabel = label
	}

	// MARK: Notifications

	func unreadCountDidChange(_ note: Notification) {

		let updatedUnreadCount = AccountManager.sharedInstance.unreadCount
		if updatedUnreadCount != unreadCount {
			unreadCount = updatedUnreadCount
		}
	}

	// MARK: Main Window

	func windowControllerWithName(_ storyboardName: String) -> NSWindowController {

		let storyboard = NSStoryboard(name: storyboardName, bundle: nil)
		return storyboard.instantiateInitialController()! as! NSWindowController
	}

	func createAndShowMainWindow() {

		if mainWindowController == nil {
			mainWindowController = windowControllerWithName("MainWindow")
		}

		mainWindowController!.showWindow(self)
	}

	// MARK: NSUserInterfaceValidations

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {

		if item.action == #selector(refreshAll(_:)) {
			return !AccountManager.sharedInstance.refreshInProgress
		}
		if item.action == #selector(addAppNews(_:)) {
			return !AccountManager.sharedInstance.anyAccountHasFeedWithURL(appNewsURLString)
		}
		return true
	}

	// MARK: Add Feed

	func addFeed(_ urlString: String?, _ name: String? = nil) {

		createAndShowMainWindow()

		addFeedController = AddFeedController(hostWindow: mainWindowController!.window!)
		addFeedController?.showAddFeedSheet(urlString, name)
	}

	// MARK: Actions

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

		AccountManager.sharedInstance.refreshAll()
	}

	@IBAction func showAddFeedWindow(_ sender: AnyObject) {

		addFeed(nil)
	}

	@IBAction func showAddFolderWindow(_ sender: AnyObject) {

		createAndShowMainWindow()

		addFolderWindowController = AddFolderWindowController()
		addFolderWindowController!.runSheetOnWindow(mainWindowController!.window!)
	}

	@IBAction func showFeedList(_ sender: AnyObject) {

		if feedListWindowController == nil {
			feedListWindowController = windowControllerWithName("FeedList")
		}
		feedListWindowController!.showWindow(self)
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
		if result == NSFileHandlingPanelOKButton {
			if let url = panel.url {
				DispatchQueue.main.async {
					self.parseAndImportOPML(url, AccountManager.sharedInstance.localAccount)
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
		if result == NSFileHandlingPanelOKButton {
			if let url = panel.url {
				DispatchQueue.main.async {
					let opmlString = AccountManager.sharedInstance.localAccount.opmlString(indentLevel: 0)
					do {
						try opmlString.write(to: url, atomically: true, encoding: String.Encoding.utf8)
					}
					catch let error as NSError {
						NSApplication.shared().presentError(error)
					}
				}
			}
		}
	}

	@IBAction func emailSupport(_ sender: AnyObject) {

		let escapedAppName = appName.replacingOccurrences(of: " ", with: "%20")
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
		let urlString = "mailto:support@ranchero.com?subject=I%20need%20help%20with%20\(escapedAppName)%20\(version)&body=I%20ran%20into%20a%20problem:%20"
		if let url = URL(string: urlString) {
			NSWorkspace.shared().open(url)
		}
	}

	@IBAction func addAppNews(_ sender: AnyObject) {

		if AccountManager.sharedInstance.anyAccountHasFeedWithURL(appNewsURLString) {
			return
		}
		addFeed(appNewsURLString, "Evergreen News")
	}

	@IBAction func openWebsite(_ sender: AnyObject) {

		openInBrowser("https://ranchero.com/evergreen/", inBackground: false)
	}

	@IBAction func openRepository(_ sender: AnyObject) {

		openInBrowser("https://github.com/brentsimmons/Evergreen", inBackground: false)
	}

	@IBAction func openBugTracker(_ sender: AnyObject) {

		openInBrowser("https://github.com/brentsimmons/Evergreen/issues", inBackground: false)
	}

	@IBAction func showHelp(_ sender: AnyObject) {

		openInBrowser("https://ranchero.com/evergreen/help/1.0/", inBackground: false)
	}
}

private extension AppDelegate {

	func parseAndImportOPML(_ url: URL, _ account: Account) {

		var fileData: Data?

		do {
			fileData = try Data(contentsOf: url)
		} catch {
			print("Error reading OPML file. \(error)")
			return
		}

		guard let opmlData = fileData else {
			return
		}

		let parserData = ParserData(data: opmlData, urlString: url.absoluteString)
		RSParseOPML(xmlData) { (opmlDocument, error) in

			if let error = error {
				NSApplication.shared().presentError(error)
				return
			}

			if let opmlDocument = opmlDocument {
				account.importOPML(opmlDocument)
				//				account.refreshAll()
			}
		}
	}
}

