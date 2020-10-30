//
//  AppDelegate.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import os.log
import UserNotifications
import Articles
import RSWeb
import Account
import RSCore
import Secrets

// If we're not going to import Sparkle, provide dummy protocols to make it easy
// for AppDelegate to comply
#if MAC_APP_STORE || TEST
protocol SPUStandardUserDriverDelegate {}
protocol SPUUpdaterDelegate {}
#else
import Sparkle
#endif

var appDelegate: AppDelegate!

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, UnreadCountProvider, SPUStandardUserDriverDelegate, SPUUpdaterDelegate
{

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")

	var userNotificationManager: UserNotificationManager!
	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var webFeedIconDownloader: WebFeedIconDownloader!
	
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

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				CoalescingQueue.standard.add(self, #selector(updateDockBadge))
				postUnreadCountDidChangeNotification()
			}
		}
	}
	
	var appName: String!
	
	private let appMovementMonitor = RSAppMovementMonitor()
	#if !MAC_APP_STORE && !TEST
	var softwareUpdater: SPUUpdater!
	#endif

	override init() {
		super.init()

		SecretsManager.provider = Secrets()
		AccountManager.shared = AccountManager(accountsFolder: Platform.dataSubfolder(forApplication: nil, folderName: "Accounts")!)
		FeedProviderManager.shared.delegate = ExtensionPointManager.shared

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWakeNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)

		appDelegate = self
	}

	// MARK: - NSApplicationDelegate
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		// TODO: add Apple Events back in
//		installAppleEventHandlers()
		
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
		
		AppDefaults.registerDefaults()
		let isFirstRun = AppDefaults.shared.isFirstRun()
		if isFirstRun {
			os_log(.debug, log: log, "Is first run.")
		}
		let localAccount = AccountManager.shared.defaultAccount

		if isFirstRun && !AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
		}


		NotificationCenter.default.addObserver(self, selector: #selector(webFeedSettingDidChange(_:)), name: .WebFeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}

		refreshTimer = AccountRefreshTimer()
		syncTimer = ArticleStatusSyncTimer()
		
		NSApplication.shared.registerForRemoteNotifications()

		UNUserNotificationCenter.current().delegate = self
		userNotificationManager = UserNotificationManager()

		// TODO: Add a debug menu
//		if AppDefaults.showDebugMenu {
//			refreshTimer!.update()
//			syncTimer!.update()
//
//			// The Web Inspector uses SPI and can never appear in a MAC_APP_STORE build.
//			#if MAC_APP_STORE
//			let debugMenu = debugMenuItem.submenu!
//			let toggleWebInspectorItemIndex = debugMenu.indexOfItem(withTarget: self, andAction: #selector(toggleWebInspectorEnabled(_:)))
//			if toggleWebInspectorItemIndex != -1 {
//				debugMenu.removeItem(at: toggleWebInspectorItemIndex)
//			}
//			#endif
//		} else {
//			debugMenuItem.menu?.removeItem(debugMenuItem)
//			DispatchQueue.main.async {
//				self.refreshTimer!.timedRefresh(nil)
//				self.syncTimer!.timedRefresh(nil)
//			}
//		}

		// TODO: Add back in crash reporter
//		#if !MAC_APP_STORE
//			DispatchQueue.main.async {
//				CrashReporter.check(appName: "NetNewsWire")
//			}
//		#endif
		
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		fireOldTimers()
	}
	
	func applicationDidResignActive(_ notification: Notification) {
		ArticleStringFormatter.emptyCaches()
	}

	func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
		AccountManager.shared.receiveRemoteNotification(userInfo: userInfo)
	}
	
	func applicationWillTerminate(_ notification: Notification) {
		shuttingDown = true
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

	@objc func userDefaultsDidChange(_ note: Notification) {
		refreshTimer?.update()
		updateDockBadge()
	}
	
	@objc func didWakeNotification(_ note: Notification) {
		fireOldTimers()
	}

	// MARK: UNUserNotificationCenterDelegate
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.banner, .badge, .sound])
	}
	
	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//		TODO: Add back in Notification handling
//		mainWindowController?.handle(response)
		completionHandler()
	}
	
	// MARK: - Dock Badge
	@objc func updateDockBadge() {
		let label = unreadCount > 0 && !AppDefaults.shared.hideDockUnreadCount ? "\(unreadCount)" : ""
		NSApplication.shared.dockTile.badgeLabel = label
	}

}

private extension AppDelegate {

	func fireOldTimers() {
		// It’s possible there’s a refresh timer set to go off in the past.
		// In that case, refresh now and update the timer.
		refreshTimer?.fireOldTimer()
		syncTimer?.fireOldTimer()
	}
	
}

/*
	the ScriptingAppDelegate protocol exposes a narrow set of accessors with
	internal visibility which are very similar to some private vars.
	
	These would be unnecessary if the similar accessors were marked internal rather than private,
	but for now, we'll keep the stratification of visibility
*/
//extension AppDelegate : ScriptingAppDelegate {
//
//	internal var scriptingMainWindowController: ScriptingMainWindowController? {
//		return mainWindowController
//	}
//
//	internal var  scriptingCurrentArticle: Article? {
//		return self.scriptingMainWindowController?.scriptingCurrentArticle
//	}
//
//	internal var  scriptingSelectedArticles: [Article] {
//		return self.scriptingMainWindowController?.scriptingSelectedArticles ?? []
//	}
//}
