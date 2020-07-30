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
import Secrets

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
	var extensionContainersFile: ExtensionContainersFile!
	var extensionFeedAddRequestFile: ExtensionFeedAddRequestFile!
	
	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
				UIApplication.shared.applicationIconBadgeNumber = unreadCount
			}
		}
	}
	
	var isSyncArticleStatusRunning = false
	var isWaitingForSyncTasks = false
	
	override init() {
		super.init()
		appDelegate = self

		SecretsManager.provider = Secrets()
		let documentAccountURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let documentAccountsFolder = documentAccountURL.appendingPathComponent("Accounts").absoluteString
		let documentAccountsFolderPath = String(documentAccountsFolder.suffix(from: documentAccountsFolder.index(documentAccountsFolder.startIndex, offsetBy: 7)))
		AccountManager.shared = AccountManager(accountsFolder: documentAccountsFolderPath)
		FeedProviderManager.shared.delegate = ExtensionPointManager.shared
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
	}
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		AppDefaults.registerDefaults()

		let isFirstRun = AppDefaults.shared.isFirstRun
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
				
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		userNotificationManager = UserNotificationManager()

		extensionContainersFile = ExtensionContainersFile()
		extensionFeedAddRequestFile = ExtensionFeedAddRequestFile()
		
		syncTimer = ArticleStatusSyncTimer()
		
		#if DEBUG
		syncTimer!.update()
		#endif
		
		return true
		
	}
	
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		DispatchQueue.main.async {
			self.resumeDatabaseProcessingIfNecessary()
			AccountManager.shared.receiveRemoteNotification(userInfo: userInfo) {
				self.suspendApplication()
				completionHandler(.newData)
			}
		}
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
	
	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.shared.lastRefresh = Date()
	}
	
	// MARK: - API
	
	func manualRefresh(errorHandler: @escaping (Error) -> ()) {
		UIApplication.shared.connectedScenes.compactMap( { $0.delegate as? SceneDelegate } ).forEach {
			$0.cleanUp(conditional: true)
		}
		AccountManager.shared.refreshAll(errorHandler: errorHandler)
	}
	
	func resumeDatabaseProcessingIfNecessary() {
		if AccountManager.shared.isSuspended {
			AccountManager.shared.resumeAll()
			os_log("Application processing resumed.", log: self.log, type: .info)
		}
	}
	
	func prepareAccountsForBackground() {
		extensionFeedAddRequestFile.suspend()
		syncTimer?.invalidate()
		scheduleBackgroundFeedRefresh()
		syncArticleStatus()
		waitForSyncTasksToFinish()
	}
	
	func prepareAccountsForForeground() {
		extensionFeedAddRequestFile.resume()
		syncTimer?.update()

		if let lastRefresh = AppDefaults.shared.lastRefresh {
			if Date() > lastRefresh.addingTimeInterval(15 * 60) {
				AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
			} else {
				AccountManager.shared.syncArticleStatusAll()
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
	
	func waitForSyncTasksToFinish() {
		guard !isWaitingForSyncTasks && UIApplication.shared.applicationState == .background else { return }
		
		isWaitingForSyncTasks = true
		
		self.waitBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask { [weak self] in
			guard let self = self else { return }
			self.completeProcessing(true)
			os_log("Accounts wait for progress terminated for running too long.", log: self.log, type: .info)
		}
		
		DispatchQueue.main.async { [weak self] in
			self?.waitToComplete() { [weak self] suspend in
				self?.completeProcessing(suspend)
			}
		}
	}
	
	func waitToComplete(completion: @escaping (Bool) -> Void) {
		guard UIApplication.shared.applicationState == .background else {
			os_log("App came back to forground, no longer waiting.", log: self.log, type: .info)
			completion(false)
			return
		}
		
		if AccountManager.shared.refreshInProgress || isSyncArticleStatusRunning {
			os_log("Waiting for sync to finish...", log: self.log, type: .info)
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
				self?.waitToComplete(completion: completion)
			}
		} else {
			os_log("Refresh progress complete.", log: self.log, type: .info)
			completion(true)
		}
	}
	
	func completeProcessing(_ suspend: Bool) {
		if suspend {
			suspendApplication()
		}
		UIApplication.shared.endBackgroundTask(self.waitBackgroundUpdateTask)
		self.waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
		isWaitingForSyncTasks = false
	}
	
	func syncArticleStatus() {
		guard !isSyncArticleStatusRunning else { return }
		
		isSyncArticleStatusRunning = true
		
		let completeProcessing = { [unowned self] in
			self.isSyncArticleStatusRunning = false
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
	
	func suspendApplication() {
		guard UIApplication.shared.applicationState == .background else { return }
		
		AccountManager.shared.suspendNetworkAll()
		AccountManager.shared.suspendDatabaseAll()

		CoalescingQueue.standard.performCallsImmediately()
		for scene in UIApplication.shared.connectedScenes {
			if let sceneDelegate = scene.delegate as? SceneDelegate {
				sceneDelegate.suspend()
			}
		}
		
		os_log("Application processing suspended.", log: self.log, type: .info)
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

		DispatchQueue.main.async {
			if AccountManager.shared.isSuspended {
				AccountManager.shared.resumeAll()
			}
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log) { [unowned self] in
				if !AccountManager.shared.isSuspended {
					self.suspendApplication()
					os_log("Account refresh operation completed.", log: self.log, type: .info)
					task.setTaskCompleted(success: true)
				}
			}
		}
					
		// set expiration handler
		task.expirationHandler = { [weak task] in
			DispatchQueue.main.sync {
				self.suspendApplication()
			}
			os_log("Accounts refresh processing terminated for running too long.", log: self.log, type: .info)
			task?.setTaskCompleted(success: false)
		}
	}
	
}
