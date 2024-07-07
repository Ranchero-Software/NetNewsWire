//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Web
import Account
@preconcurrency import BackgroundTasks
import os.log
import Secrets
import WidgetKit
import Core
import Images

@MainActor var appDelegate: AppDelegate!

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
	
	nonisolated(unsafe) let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")
	
	var userNotificationManager: UserNotificationManager!
	var extensionContainersFile: ExtensionContainersFile!
	var extensionFeedAddRequestFile: ExtensionFeedAddRequestFile!
	
	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				handleUnreadCountDidChange()
			}
		}
	}
	
	var isSyncArticleStatusRunning = false
	var isWaitingForSyncTasks = false
	
	let accountManager: AccountManager

	private var secretsProvider = Secrets()
	
	override init() {

		let documentFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let documentAccountsFolder = documentFolder.appendingPathComponent("Accounts").absoluteString
		let documentAccountsFolderPath = String(documentAccountsFolder.suffix(from: documentAccountsFolder.index(documentAccountsFolder.startIndex, offsetBy: 7)))
		self.accountManager = AccountManager(accountsFolder: documentAccountsFolderPath, secretsProvider: secretsProvider)
		AccountManager.shared = accountManager

		super.init()

		appDelegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
	}
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		AppDefaults.registerDefaults()

		let isFirstRun = AppDefaults.shared.isFirstRun
		if isFirstRun {
			os_log("Is first run.", log: log, type: .info)
		}
		
		if isFirstRun && !accountManager.anyAccountHasAtLeastOneFeed() {
			let localAccount = accountManager.defaultAccount
			DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
		}
		
		FaviconGenerator.faviconTemplateImage = AppAssets.faviconTemplateImage

		registerBackgroundTasks()
		CacheCleaner.purgeIfNecessary()
		initializeDownloaders()
		initializeHomeScreenQuickActions()
		
		Task { @MainActor in
			self.unreadCount = accountManager.unreadCount
		}

		UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .sound, .alert]) { (granted, error) in
			if granted {
				Task { @MainActor in
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
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {

		resumeDatabaseProcessingIfNecessary()
		await accountManager.receiveRemoteNotification(userInfo: userInfo)
		suspendApplication()
		return .newData
	}

	func applicationWillTerminate(_ application: UIApplication) {
		shuttingDown = true
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		
		ArticleStringFormatter.emptyCaches()
		MultilineUILabelSizer.emptyCache()
		SingleLineUILabelSizer.emptyCache()
		IconImageCache.shared.emptyCache()
		accountManager.emptyCaches()

		Task.detached {
			await DownloadWithCacheManager.shared.cleanupCache()
		}
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = accountManager.unreadCount
		}
	}
	
	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.shared.lastRefresh = Date()
	}
	
	// MARK: - API
	
	func manualRefresh(errorHandler: @escaping (Error) -> ()) {

		let sceneDelegates = UIApplication.shared.connectedScenes.compactMap{ $0.delegate as? SceneDelegate }
		for sceneDelegate in sceneDelegates {
			sceneDelegate.cleanUp(conditional: true)
		}

		Task { @MainActor in
			await self.accountManager.refreshAll(errorHandler: errorHandler)
		}
	}
	
	func resumeDatabaseProcessingIfNecessary() {
		if accountManager.isSuspended {
			accountManager.resumeAll()
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

		Task { @MainActor in
			if let lastRefresh = AppDefaults.shared.lastRefresh {
				if Date() > lastRefresh.addingTimeInterval(15 * 60) {
					await accountManager.refreshAll(errorHandler: ErrorHandler.log)
				} else {
					await accountManager.syncArticleStatusAll()
				}
			} else {
				await accountManager.refreshAll(errorHandler: ErrorHandler.log)
			}
		}
	}

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		
		completionHandler([.list, .banner, .badge, .sound])
    }
	
	nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

		MainActor.assumeIsolated {
			defer { completionHandler() }

			let userInfo = response.notification.request.content.userInfo

			switch response.actionIdentifier {
			case "MARK_AS_READ":
				handleMarkAsRead(userInfo: userInfo)
			case "MARK_AS_STARRED":
				handleMarkAsStarred(userInfo: userInfo)
			default:
				if let sceneDelegate = response.targetScene?.delegate as? SceneDelegate {
					sceneDelegate.handle(response)
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
						sceneDelegate.coordinator.dismissIfLaunchingFromExternalAction()
					})
				}
			}
		}
    }
}

// MARK: App Initialization

private extension AppDelegate {

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
			os_log("App came back to foreground, no longer waiting.", log: self.log, type: .info)
			completion(false)
			return
		}
		
		if accountManager.refreshInProgress || isSyncArticleStatusRunning {
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
		
		Task { @MainActor in
			await self.accountManager.syncArticleStatusAll()
			completeProcessing()
		}
	}
	
	func suspendApplication() {
		guard UIApplication.shared.applicationState == .background else { return }
		
		accountManager.suspendNetworkAll()
		accountManager.suspendDatabaseAll()
		ArticleThemeDownloader.cleanUp()

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
				Task { @MainActor in
					os_log(.error, log: self.log, "Could not schedule app refresh: %@", error.localizedDescription)
				}
			}
		}
	}
	
	/// Performs background feed refresh.
	/// - Parameter task: `BGAppRefreshTask`
	/// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
	func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {
		
		scheduleBackgroundFeedRefresh() // schedule next refresh
		
		os_log("Woken to perform account refresh.", log: self.log, type: .info)

		Task { @MainActor in
			if self.accountManager.isSuspended {
				self.accountManager.resumeAll()
			}
			await self.accountManager.refreshAll(errorHandler: ErrorHandler.log)
			if !self.accountManager.isSuspended {
				try? WidgetDataEncoder.shared.encodeWidgetData()
				self.suspendApplication()
				os_log("Account refresh operation completed.", log: self.log, type: .info)
				task.setTaskCompleted(success: true)
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

// Handle Notification Actions

private extension AppDelegate {
	
	@MainActor func handleMarkAsRead(userInfo: [AnyHashable: Any]) {

		guard let articlePathInfo = ArticlePathInfo(userInfo: userInfo) else {
			return
		}

		resumeDatabaseProcessingIfNecessary()

		guard let accountID = articlePathInfo.accountID, let account = accountManager.existingAccount(with: accountID) else {
			os_log(.debug, "No account found from notification.")
			return
		}
		guard let articleID = articlePathInfo.articleID else {
			os_log(.debug, "No articleID found from notification.")
			return
		}

		Task { @MainActor in
			guard let articles = try? await account.articles(for: .articleIDs([articleID])) else {
				os_log(.debug, "No article found from search using %@", articleID)
				return
			}

			try? await account.markArticles(articles, statusKey: .read, flag: true)

			self.prepareAccountsForBackground()

			try? await account.syncArticleStatus()
			if !self.accountManager.isSuspended {
				try? WidgetDataEncoder.shared.encodeWidgetData()
				self.prepareAccountsForBackground()
				self.suspendApplication()
			}
		}
	}

	@MainActor func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {

		guard let articlePathInfo = ArticlePathInfo(userInfo: userInfo) else {
			return
		}

		resumeDatabaseProcessingIfNecessary()

		guard let accountID = articlePathInfo.accountID, let account = accountManager.existingAccount(with: accountID) else {
			os_log(.debug, "No account found from notification.")
			return
		}
		guard let articleID = articlePathInfo.articleID else {
			os_log(.debug, "No articleID found from notification.")
			return
		}

		Task { @MainActor in

			guard let articles = try? await account.articles(for: .articleIDs([articleID])) else {
				os_log(.debug, "No article found from search using %@", articleID)
				return
			}

			try? await account.markArticles(articles, statusKey: .starred, flag: true)

			try? await account.syncArticleStatus()
			if !self.accountManager.isSuspended {
				try? WidgetDataEncoder.shared.encodeWidgetData()
				self.prepareAccountsForBackground()
				self.suspendApplication()
			}
		}
	}
}
