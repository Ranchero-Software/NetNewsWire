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
import UserNotifications
import BackgroundTasks
import os.log

var appDelegate: AppDelegate!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate, UnreadCountProvider {
	
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
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "application")
	
	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var feedIconDownloader: FeedIconDownloader!
	
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
		
		registerBackgroundTasks()
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		
		// Reinitialize the shared state as early as possible
		_ = AccountManager.shared
		
	}
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		
		AppDefaults.registerDefaults()
		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			os_log("Is first run.", log: log, type: .info)
		}
		
		let localAccount = AccountManager.shared.defaultAccount
		DefaultFeedsImporter.importIfNeeded(isFirstRun, account: localAccount)
		
		let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let faviconsFolderURL = tempDir.appendingPathComponent("Favicons")
		try! FileManager.default.createDirectory(at: faviconsFolderURL, withIntermediateDirectories: true, attributes: nil)
		let faviconsFolder = faviconsFolderURL.absoluteString
		let faviconsFolderPath = faviconsFolder.suffix(from: faviconsFolder.index(faviconsFolder.startIndex, offsetBy: 7))
		faviconDownloader = FaviconDownloader(folder: String(faviconsFolderPath))
		
		let imagesFolderURL = tempDir.appendingPathComponent("Images")
		let imagesFolder = imagesFolderURL.absoluteString
		let imagesFolderPath = imagesFolder.suffix(from: imagesFolder.index(imagesFolder.startIndex, offsetBy: 7))
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
		imageDownloader = ImageDownloader(folder: String(imagesFolderPath))
		
		authorAvatarDownloader = AuthorAvatarDownloader(imageDownloader: imageDownloader)
		
		let tempFolder = tempDir.absoluteString
		let tempFolderPath = tempFolder.suffix(from: tempFolder.index(tempFolder.startIndex, offsetBy: 7))
		feedIconDownloader = FeedIconDownloader(imageDownloader: imageDownloader, folder: String(tempFolderPath))
		
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
		
		syncTimer = ArticleStatusSyncTimer()
		
		#if DEBUG
		syncTimer!.update()
		#endif
		
		return true
		
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
		shuttingDown = true
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		scheduleBackgroundFeedRefresh()
	}
	
	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.lastRefresh = Date()
	}
	
	// MARK: - API
	
	func prepareAccountsForBackground() {
		syncTimer?.invalidate()
		
		// Schedule background app refresh
		scheduleBackgroundFeedRefresh()
		
		// Sync article status
		let completeProcessing = { [unowned self] in
			UIApplication.shared.endBackgroundTask(self.syncBackgroundUpdateTask)
			self.syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		}
		
		DispatchQueue.global(qos: .background).async {
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
	
}


// MARK: - Background Tasks
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
		request.earliestBeginDate = Date(timeIntervalSinceNow: AppDefaults.refreshInterval.inSeconds())
		do {
			try BGTaskScheduler.shared.submit(request)
		} catch {
			os_log(.error, log: self.log, "Could not schedule app refresh: %@", error.localizedDescription)
		}
	}
	
	/// Performs background feed refresh.
	/// - Parameter task: `BGAppRefreshTask`
	/// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
	func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {
		
		scheduleBackgroundFeedRefresh() // schedule next refresh
		
		var startingUnreadCount = 0
		
		DispatchQueue.global(qos: .background).async { [unowned self] in
			
			os_log("Woken to perform account refresh.", log: self.log, type: .info)
	
			os_log("Getting unread count.", log: self.log, type: .info)
			while(!AccountManager.shared.isUnreadCountsInitialized) {
				os_log("Waiting for unread counts to be initialized...", log: self.log, type: .info)
				sleep(1)
			}
			os_log(.info, log: self.log, "Got unread count: %i", self.unreadCount)
			startingUnreadCount = self.unreadCount
			
			DispatchQueue.main.async {
				AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
			}
			os_log("Accounts requested to begin refresh.", log: self.log, type: .info)
			
			sleep(1)
			while (!AccountManager.shared.combinedRefreshProgress.isComplete) {
				os_log("Waiting for account refresh processing to complete...", log: self.log, type: .info)
				sleep(1)
			}
			
			if startingUnreadCount < self.unreadCount {
				os_log("Updating unread count badge, posting notification.", log: self.log, type: .info)
				self.sendReceivedArticlesUserNotification(newArticleCount: self.unreadCount - startingUnreadCount)
				task.setTaskCompleted(success: true)
			} else {
				os_log("Account refresh operation completed.", log: self.log, type: .info)
				task.setTaskCompleted(success: true)
			}
		}
		
		// set expiration handler
		task.expirationHandler = {
			os_log("Accounts refresh processing terminated for running too long.", log: self.log, type: .info)
			task.setTaskCompleted(success: false)
		}
	}
	
}

private extension AppDelegate {
	
	
	func sendReceivedArticlesUserNotification(newArticleCount: Int) {
		
		let content = UNMutableNotificationContent()
		content.title = NSLocalizedString("Article Download", comment: "New Articles")
		
		let body: String = {
			if newArticleCount == 1 {
				return NSLocalizedString("You have downloaded 1 new article.", comment: "Article Downloaded")
			} else {
				let formatString = NSLocalizedString("You have downloaded %d new articles.", comment: "Articles Downloaded")
				return NSString.localizedStringWithFormat(formatString as NSString, newArticleCount) as String
			}
		}()
		
		content.body = body
		content.sound = UNNotificationSound.default
		
		let request = UNNotificationRequest.init(identifier: "NewArticlesReceived", content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
		
	}
	
}
