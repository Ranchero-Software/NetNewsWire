//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import RSWeb
import Account
import BackgroundTasks
import os.log

var appDelegate: AppDelegate!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UnreadCountProvider {
	
	private var bgTaskDispatchQueue = DispatchQueue.init(label: "BGTaskScheduler")
	
	private var waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
	private var syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
	
	var syncTimer: ArticleStatusSyncTimer?
	
	var shuttingDown = false {
		didSet {
			if shuttingDown {
				syncTimer?.shuttingDown = shuttingDown
				syncTimer?.invalidate()
			}
		}
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")
	
	var userNotificationManager: UserNotificationManager!
	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var webFeedIconDownloader: WebFeedIconDownloader!
	
	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
				UIApplication.shared.applicationIconBadgeNumber = unreadCount
			}
		}
	}
	
	override init() {
		super.init()
		appDelegate = self

		// Force lazy initialization of the web view provider so that it can warm up the queue of prepared web views
		let _ = ArticleViewControllerWebViewProvider.shared
		AccountManager.shared = AccountManager()
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
	}
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		AppDefaults.registerDefaults()

		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			os_log("Is first run.", log: log, type: .info)
		}
		
		if isFirstRun && !AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			let localAccount = AccountManager.shared.defaultAccount
			DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
		}
		
		registerBackgroundTasks()
		CacheCleaner.purgeIfNecessary()
		initializeDownloaders()
		initializeHomeScreenQuickActions()
		
		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}
		
		UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .sound, .alert]) { (granted, error) in
			if granted {
				DispatchQueue.main.async {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		userNotificationManager = UserNotificationManager()

		syncTimer = ArticleStatusSyncTimer()
		
		#if DEBUG
		syncTimer!.update()
		#endif
		
		return true
		
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
		shuttingDown = true
		AccountManager.shared.suspendAll()
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}
	
	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.lastRefresh = Date()
	}
	
	// MARK: - API
	
	func prepareAccountsForBackground() {
		syncTimer?.invalidate()
		scheduleBackgroundFeedRefresh()
		waitForProgressToFinish()
		syncArticleStatus()
	}
	
	func prepareAccountsForForeground() {
		if let lastRefresh = AppDefaults.lastRefresh {
			if Date() > lastRefresh.addingTimeInterval(15 * 60) {
				AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
			} else {
				AccountManager.shared.syncArticleStatusAll()
				syncTimer?.update()
			}
		} else {
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
		}
	}
	
	func logMessage(_ message: String, type: LogItem.ItemType) {
		print("logMessage: \(message) - \(type)")
		
	}
	
	func logDebugMessage(_ message: String) {
		logMessage(message, type: .debug)
	}
	
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
	
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		defer { completionHandler() }
		
		if let sceneDelegate = response.targetScene?.delegate as? SceneDelegate {
			sceneDelegate.handle(response)
		}
        
    }
	
}

// MARK: App Initialization

private extension AppDelegate {
	
	private func initializeDownloaders() {
		let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let faviconsFolderURL = tempDir.appendingPathComponent("Favicons")
		let imagesFolderURL = tempDir.appendingPathComponent("Images")
		
		try! FileManager.default.createDirectory(at: faviconsFolderURL, withIntermediateDirectories: true, attributes: nil)
		let faviconsFolder = faviconsFolderURL.absoluteString
		let faviconsFolderPath = faviconsFolder.suffix(from: faviconsFolder.index(faviconsFolder.startIndex, offsetBy: 7))
		faviconDownloader = FaviconDownloader(folder: String(faviconsFolderPath))
		
		let imagesFolder = imagesFolderURL.absoluteString
		let imagesFolderPath = imagesFolder.suffix(from: imagesFolder.index(imagesFolder.startIndex, offsetBy: 7))
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
		imageDownloader = ImageDownloader(folder: String(imagesFolderPath))
		
		authorAvatarDownloader = AuthorAvatarDownloader(imageDownloader: imageDownloader)
		
		let tempFolder = tempDir.absoluteString
		let tempFolderPath = tempFolder.suffix(from: tempFolder.index(tempFolder.startIndex, offsetBy: 7))
		webFeedIconDownloader = WebFeedIconDownloader(imageDownloader: imageDownloader, folder: String(tempFolderPath))
	}
	
	private func initializeHomeScreenQuickActions() {
		let unreadTitle = NSLocalizedString("First Unread", comment: "First Unread")
		let unreadIcon = UIApplicationShortcutIcon(systemImageName: "chevron.down.circle")
		let unreadItem = UIApplicationShortcutItem(type: "com.ranchero.NetNewsWire.FirstUnread", localizedTitle: unreadTitle, localizedSubtitle: nil, icon: unreadIcon, userInfo: nil)
		
		let searchTitle = NSLocalizedString("Search", comment: "Search")
		let searchIcon = UIApplicationShortcutIcon(systemImageName: "magnifyingglass")
		let searchItem = UIApplicationShortcutItem(type: "com.ranchero.NetNewsWire.ShowSearch", localizedTitle: searchTitle, localizedSubtitle: nil, icon: searchIcon, userInfo: nil)

		let addTitle = NSLocalizedString("Add Feed", comment: "Add Feed")
		let addIcon = UIApplicationShortcutIcon(systemImageName: "plus")
		let addItem = UIApplicationShortcutItem(type: "com.ranchero.NetNewsWire.ShowAdd", localizedTitle: addTitle, localizedSubtitle: nil, icon: addIcon, userInfo: nil)

		UIApplication.shared.shortcutItems = [addItem, searchItem, unreadItem]
	}
	
}

// MARK: Go To Background
private extension AppDelegate {
	
	func waitForProgressToFinish() {
		let completeProcessing = { [unowned self] in
			AccountManager.shared.suspendAll()
			UIApplication.shared.endBackgroundTask(self.waitBackgroundUpdateTask)
			self.waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		}
		
		self.waitBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask {
			completeProcessing()
			os_log("Accounts wait for progress terminated for running too long.", log: self.log, type: .info)
		}
		
		DispatchQueue.main.async { [weak self] in
			self?.waitToComplete() {
				completeProcessing()
			}
		}
	}
	
	func waitToComplete(completion: @escaping () -> Void) {
		guard UIApplication.shared.applicationState != .active else {
			os_log("App came back to forground, no longer waiting.", log: self.log, type: .info)
			completion()
			return
		}
		
		if AccountManager.shared.refreshInProgress {
			os_log("Waiting for refresh progress to finish...", log: self.log, type: .info)
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
				self?.waitToComplete() {
					completion()
				}
			}
		} else {
			os_log("Refresh progress complete.", log: self.log, type: .info)
			completion()
		}
	}
	
	func syncArticleStatus() {
		let completeProcessing = { [unowned self] in
			UIApplication.shared.endBackgroundTask(self.syncBackgroundUpdateTask)
			self.syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		}
		
		self.syncBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask {
			completeProcessing()
			os_log("Accounts sync processing terminated for running too long.", log: self.log, type: .info)
		}
		
		DispatchQueue.main.async {
			AccountManager.shared.syncArticleStatusAll() {
				completeProcessing()
			}
		}
	}
	
}

// MARK: Background Tasks

private extension AppDelegate {

	/// Register all background tasks.
	func registerBackgroundTasks() {
		// Register background feed refresh.
		BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.ranchero.NetNewsWire.FeedRefresh", using: nil) { (task) in
			self.performBackgroundFeedRefresh(with: task as! BGAppRefreshTask)
		}
	}
	
	/// Schedules a background app refresh based on `AppDefaults.refreshInterval`.
	func scheduleBackgroundFeedRefresh() {
		let request = BGAppRefreshTaskRequest(identifier: "com.ranchero.NetNewsWire.FeedRefresh")
		request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

		// We send this to a dedicated serial queue because as of 11/05/19 on iOS 13.2 the call to the
		// task scheduler can hang indefinitely.
		bgTaskDispatchQueue.async {
			do {
				try BGTaskScheduler.shared.submit(request)
			} catch {
				os_log(.error, log: self.log, "Could not schedule app refresh: %@", error.localizedDescription)
			}
		}
	}
	
	/// Performs background feed refresh.
	/// - Parameter task: `BGAppRefreshTask`
	/// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
	func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {
		
		scheduleBackgroundFeedRefresh() // schedule next refresh
		
		os_log("Woken to perform account refresh.", log: self.log, type: .info)

		DispatchQueue.main.async { [weak task] in
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log) {
				AccountManager.shared.saveAll()
				os_log("Account refresh operation completed.", log: self.log, type: .info)
				task?.setTaskCompleted(success: true)
			}
		}
					
		// set expiration handler
		task.expirationHandler = { [weak task] in
			os_log("Accounts refresh processing terminated for running too long.", log: self.log, type: .info)
			task?.setTaskCompleted(success: false)
		}
	}
	
}
