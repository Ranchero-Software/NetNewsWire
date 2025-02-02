//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import BackgroundTasks
import os
import RSCore
import Account

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UnreadCountProvider {

	var window: UIWindow?

	private var bgTaskDispatchQueue = DispatchQueue.init(label: "BGTaskScheduler")
	private var waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
	private var syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid

	private var coordinator: SceneCoordinator?

	var syncTimer: ArticleStatusSyncTimer?

	private var shuttingDown = false {
		didSet {
			if shuttingDown {
				syncTimer?.shuttingDown = shuttingDown
				syncTimer?.invalidate()
			}
		}
	}

	private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Application")

	var userNotificationManager: UserNotificationManager!
	var extensionContainersFile: ExtensionContainersFile!
	var extensionFeedAddRequestFile: ExtensionFeedAddRequestFile!
	var widgetDataEncoder: WidgetDataEncoder!

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
				UNUserNotificationCenter.current().setBadgeCount(unreadCount)
			}
		}
	}

	var isSyncArticleStatusRunning = false
	var isWaitingForSyncTasks = false

	override init() {
		super.init()

		_ = AccountManager.shared
		_ = ArticleThemesManager.shared

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidTriggerManualRefresh(_:)), name: .userDidTriggerManualRefresh, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
	}

	// MARK: - Lifecycle

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		AppDefaults.registerDefaults()

		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			logger.info("Is first run.")
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

		UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, _) in
			if granted {
				DispatchQueue.main.async {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		userNotificationManager = UserNotificationManager()

		extensionContainersFile = ExtensionContainersFile()
		extensionFeedAddRequestFile = ExtensionFeedAddRequestFile()

		widgetDataEncoder = WidgetDataEncoder()

		syncTimer = ArticleStatusSyncTimer()

		#if DEBUG
		syncTimer!.update()
		#endif

		// Create window.
		let window = UIWindow(frame: UIScreen.main.bounds)
		self.window = window

		// Create UI and add it to window.
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		let rootSplitViewController = storyboard.instantiateInitialViewController() as! RootSplitViewController
		rootSplitViewController.presentsWithGesture = true
		rootSplitViewController.showsSecondaryOnlyButton = true
		rootSplitViewController.preferredDisplayMode = .oneBesideSecondary

		coordinator = SceneCoordinator(rootSplitViewController: rootSplitViewController)
		rootSplitViewController.coordinator = coordinator
		rootSplitViewController.delegate = coordinator

		window.rootViewController = rootSplitViewController

		window.tintColor = AppColor.accent
		updateUserInterfaceStyle()
		UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()

		window.makeKeyAndVisible()

		Task { @MainActor in
			// Ensure Feeds view shows on first run on iPad — otherwise the UI is empty.
			if UIDevice.current.userInterfaceIdiom == .pad && AppDefaults.isFirstRun {
				rootSplitViewController.show(.primary)
			}
		}

		return true
	}

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		DispatchQueue.main.async {
			AccountManager.shared.resumeAllIfSuspended()
			AccountManager.shared.receiveRemoteNotification(userInfo: userInfo) {
				self.suspendApplication()
				completionHandler(.newData)
			}
		}
    }

	func applicationWillTerminate(_ application: UIApplication) {
		shuttingDown = true
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		IconImageCache.shared.emptyCache()
	}

	// MARK: - Notifications

	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.lastRefresh = Date()
	}

	@objc func userDidTriggerManualRefresh(_ note: Notification) {

		guard let errorHandler = note.userInfo?[UserInfoKey.errorHandler] as? ErrorHandlerBlock else {
			assertionFailure("Expected errorHandler in .userDidTriggerManualRefresh userInfo")
			return
		}

		manualRefresh(errorHandler: errorHandler)
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		updateUserInterfaceStyle()
	}

	// MARK: - API

	func manualRefresh(errorHandler: @escaping ErrorHandlerBlock) {
		assert(Thread.isMainThread)
		coordinator?.cleanUp(conditional: true)
		AccountManager.shared.refreshAll(errorHandler: errorHandler)
	}

	func prepareAccountsForBackground() {
		extensionFeedAddRequestFile.suspend()
		syncTimer?.invalidate()
		scheduleBackgroundFeedRefresh()
		syncArticleStatus()
		widgetDataEncoder.encode()
		waitForSyncTasksToFinish()
	}

	func prepareAccountsForForeground() {
		extensionFeedAddRequestFile.resume()
		syncTimer?.update()

		if let lastRefresh = AppDefaults.lastRefresh {
			if Date() > lastRefresh.addingTimeInterval(15 * 60) {
				AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
			} else {
				AccountManager.shared.syncArticleStatusAll()
			}
		} else {
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
		}
	}

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.list, .banner, .badge, .sound])
    }

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		defer { completionHandler() }

		let userInfo = response.notification.request.content.userInfo

		switch response.actionIdentifier {
		case "MARK_AS_READ":
			handleMarkAsRead(userInfo: userInfo)
		case "MARK_AS_STARRED":
			handleMarkAsStarred(userInfo: userInfo)
		default:
			handle(response)
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.coordinator?.dismissIfLaunchingFromExternalAction()
			}
		}
	}
}

// MARK: - App Initialization

private extension AppDelegate {

	private func initializeDownloaders() {
		let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let imagesFolderURL = tempDir.appendingPathComponent("Images")

		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
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

// MARK: - Private

private extension AppDelegate {

	func updateUserInterfaceStyle() {

		assert(Thread.isMainThread)
		guard let window else {
			// Could be nil legitimately — this can get called before window is set up.
			return
		}

		let updatedStyle = AppDefaults.userInterfaceColorPalette.uiUserInterfaceStyle
		if window.overrideUserInterfaceStyle != updatedStyle {
			window.overrideUserInterfaceStyle = updatedStyle
		}
	}
}

// MARK: - Go To Background

private extension AppDelegate {

	func waitForSyncTasksToFinish() {
		guard !isWaitingForSyncTasks && UIApplication.shared.applicationState == .background else { return }

		isWaitingForSyncTasks = true

		self.waitBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask { [weak self] in
			guard let self = self else { return }
			self.completeProcessing(true)
			logger.info("Accounts wait for progress terminated for running too long.")
		}

		DispatchQueue.main.async { [weak self] in
			self?.waitToComplete { [weak self] suspend in
				self?.completeProcessing(suspend)
			}
		}
	}

	func waitToComplete(completion: @escaping (Bool) -> Void) {
		guard UIApplication.shared.applicationState == .background else {
			logger.info("App came back to foreground, no longer waiting.")
			completion(false)
			return
		}

		if AccountManager.shared.refreshInProgress || isSyncArticleStatusRunning || widgetDataEncoder.isRunning {
			logger.info("Waiting for sync to finish…")
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
				self?.waitToComplete(completion: completion)
			}
		} else {
			logger.info("Refresh progress complete.")
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
			self.logger.info("Accounts sync processing terminated for running too long.")
		}

		DispatchQueue.main.async {
			AccountManager.shared.syncArticleStatusAll {
				completeProcessing()
			}
		}
	}

	func suspendApplication() {
		guard UIApplication.shared.applicationState == .background else { return }

		AccountManager.shared.suspendNetworkAll()
		AccountManager.shared.suspendDatabaseAll()
		ArticleThemeDownloader.shared.cleanUp()

		CoalescingQueue.standard.performCallsImmediately()
		coordinator?.suspend()
		logger.info("Application processing suspended.")
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
		request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

		// We send this to a dedicated serial queue because as of 11/05/19 on iOS 13.2 the call to the
		// task scheduler can hang indefinitely.
		bgTaskDispatchQueue.async {
			do {
				try BGTaskScheduler.shared.submit(request)
			} catch {
				self.logger.error("Could not schedule app refresh: \(error.localizedDescription)")
			}
		}
	}

	/// Performs background feed refresh.
	/// - Parameter task: `BGAppRefreshTask`
	/// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
	func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {

		scheduleBackgroundFeedRefresh() // schedule next refresh

		logger.info("Woken to perform account refresh.")

		DispatchQueue.main.async {
			if AccountManager.shared.isSuspended {
				AccountManager.shared.resumeAll()
			}
			AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log) { [unowned self] in
				if !AccountManager.shared.isSuspended {
					self.suspendApplication()
					logger.info("Account refresh operation completed.")
					task.setTaskCompleted(success: true)
				}
			}
		}

		// set expiration handler
		task.expirationHandler = { [weak task] in
			self.logger.info("Accounts refresh processing terminated for running too long.")
			DispatchQueue.main.async {
				self.suspendApplication()
				task?.setTaskCompleted(success: false)
			}
		}
	}
}

// MARK: - Handle Notification Actions

private extension AppDelegate {

	func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}
		AccountManager.shared.resumeAllIfSuspended()
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
		self.prepareAccountsForBackground()
		account!.syncArticleStatus(completion: { [weak self] _ in
			if !AccountManager.shared.isSuspended {
				self?.prepareAccountsForBackground()
				self?.suspendApplication()
			}
		})
	}

	func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}
		AccountManager.shared.resumeAllIfSuspended()
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
		account!.syncArticleStatus(completion: { [weak self] _ in
			if !AccountManager.shared.isSuspended {
				self?.prepareAccountsForBackground()
				self?.suspendApplication()
			}
		})
	}

	func handle(_ response: UNNotificationResponse) {
		AccountManager.shared.resumeAllIfSuspended()
		coordinator?.handle(response)
	}
}
