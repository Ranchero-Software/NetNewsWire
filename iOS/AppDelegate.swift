//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
@preconcurrency import BackgroundTasks
import os
import WidgetKit
import RSCore
import RSWeb
import Account
import Articles
import Secrets
import ErrorLog
import Images

@MainActor var appDelegate: AppDelegate!

@main
@MainActor final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, UnreadCountProvider {

	private let backgroundTaskDispatchQueue = DispatchQueue.init(label: "BGTaskScheduler")

	var shuttingDown = false {
		didSet {
			if shuttingDown {
				ArticleStatusSyncTimer.shared.stop()
			}
		}
	}

	nonisolated private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "Application")

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
				updateBadge()
			}
		}
	}

	var isSyncArticleStatusRunning = false
	var isWaitingForSyncTasks = false

	override init() {
		super.init()
		appDelegate = self

		AccountManager.shared.start()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		FaviconGenerator.templateImage = Assets.Images.faviconTemplate

		WebViewConfiguration.resolveBrowserUserAgent()
		Task {
			await WebViewConfiguration.compileContentBlockingRules()
		}
		AppDefaults.registerDefaults()

		let isFirstRun = AppDefaults.shared.isFirstRun
		if isFirstRun {
			Self.logger.info("Is first run.")
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
			// Force the badge to update on launch.
			self.updateBadge()
		}

		UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, _) in
			if granted {
				DispatchQueue.main.async {
					UIApplication.shared.registerForRemoteNotifications()
				}
			}
		}

		UNUserNotificationCenter.current().delegate = self
		UserNotificationManager.shared.start()

		ArticleThemesManager.shared.start()
		NetworkMonitor.shared.start()

#if !SKIP_APP_GROUP_ACCESS
		ExtensionContainersFile.shared.start()
		ExtensionFeedAddRequestFile.shared.start()
#endif

		#if DEBUG
		ArticleStatusSyncTimer.shared.update()
		#endif

		return true

	}

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		Task { @MainActor in
			self.resumeIfNecessary()
			await AccountManager.shared.receiveRemoteNotification(userInfo: userInfo)
			self.suspendApplication()
			completionHandler(.newData)
		}
    }

	func applicationWillTerminate(_ application: UIApplication) {
		shuttingDown = true
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		updateBadge()
	}

	func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
		AppNotification.postLowMemory()
	}

	private func updateBadge() {
		assert(unreadCount == AccountManager.shared.unreadCount)
		UNUserNotificationCenter.current().setBadgeCount(unreadCount)
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

	func manualRefresh(errorHandler: @escaping @Sendable (Error) -> Void) {
		let sceneDelegates = UIApplication.shared.connectedScenes.compactMap { $0.delegate as? SceneDelegate }
		for sceneDelegate in sceneDelegates {
			sceneDelegate.cleanUp(conditional: true)
		}
		AccountManager.shared.refreshAllWithoutWaiting(errorHandler: errorHandler)
	}

	/// Un-suspend network activity if it was suspended on background entry.
	func resumeIfNecessary() {
		AppNotification.postAppDidBecomeActive()
		if AccountManager.shared.isSuspended {
			AccountManager.shared.resumeAll()
			Self.logger.info("Application processing resumed.")
		}
	}

	func prepareAccountsForBackground() {
		updateBadge()

#if !SKIP_APP_GROUP_ACCESS
		ExtensionFeedAddRequestFile.shared.suspend()
#endif

		ArticleStatusSyncTimer.shared.invalidate()
		scheduleBackgroundFeedRefresh()
		syncArticleStatus()
		WidgetDataEncoder.shared?.encode()
		waitForSyncTasksToFinish()
	}

	func prepareAccountsForForeground() {
		updateBadge()
#if !SKIP_APP_GROUP_ACCESS
		ExtensionFeedAddRequestFile.shared.resume()
#endif
		ArticleStatusSyncTimer.shared.update()

		if let lastRefresh = AppDefaults.shared.lastRefresh {
			if Date() > lastRefresh.addingTimeInterval(15 * 60) {
				AccountManager.shared.refreshAllWithoutWaiting(errorHandler: ErrorHandler.log)
			} else {
				AccountManager.shared.syncArticleStatusAllWithoutWaiting()
			}
		} else {
			AccountManager.shared.refreshAllWithoutWaiting(errorHandler: ErrorHandler.log)
		}
	}

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.list, .banner, .badge, .sound])
    }

	// Wrapper to safely transfer non-Sendable values to MainActor
	private struct UnsafeSendable<T>: @unchecked Sendable {
		let value: T
	}

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

		let wrappedResponse = UnsafeSendable(value: response)
		let wrappedCompletionHandler = UnsafeSendable(value: completionHandler)

		Task { @MainActor in
			handle(notificationResponse: wrappedResponse.value)
			wrappedCompletionHandler.value()
		}
    }

	private func handle(notificationResponse response: UNNotificationResponse) {

		let userInfo = response.notification.request.content.userInfo

		switch response.actionIdentifier {
		case UserNotificationManager.ActionIdentifier.markAsRead:
			handleMarkAsRead(userInfo: userInfo)
		case UserNotificationManager.ActionIdentifier.markAsStarred:
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

// MARK: App Initialization

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

// MARK: Go To Background

private extension AppDelegate {

	func waitForSyncTasksToFinish() {
		guard !isWaitingForSyncTasks && UIApplication.shared.applicationState == .background else {
			return
		}

		isWaitingForSyncTasks = true

		var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

		/// Make sure this run’s background task is ended exactly once.
		func endWaitBackgroundTask() {
			guard backgroundTaskIdentifier != .invalid else {
				return
			}
			UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
			backgroundTaskIdentifier = .invalid
		}

		let waitTask = Task { @MainActor in
			let shouldSuspend = await waitToComplete()
			isWaitingForSyncTasks = false
			if shouldSuspend {
				suspendApplication()
			}
			endWaitBackgroundTask()
		}

		backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Wait for Sync Tasks") {
			waitTask.cancel()
			self.suspendApplication()
			endWaitBackgroundTask()
			Self.logger.info("Accounts wait for progress terminated for running too long.")
		}
	}

	/// Wait for the refresh, status sync, and widget encode to finish. Returns whether the app should suspend.
	func waitToComplete() async -> Bool {
		while !Task.isCancelled {
			guard UIApplication.shared.applicationState == .background else {
				Self.logger.info("App came back to foreground, no longer waiting.")
				return false
			}

			if AccountManager.shared.refreshInProgress || isSyncArticleStatusRunning || WidgetDataEncoder.shared?.isRunning ?? false {
				Self.logger.info("Waiting for sync to finish…")
				try? await Task.sleep(for: .seconds(1))
			} else {
				Self.logger.info("Refresh progress complete.")
				return true
			}
		}

		return false
	}

	func syncArticleStatus() {
		guard !isSyncArticleStatusRunning else {
			return
		}

		isSyncArticleStatusRunning = true

		var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

		/// Make sure this run’s background task is ended exactly once.
		func endSyncBackgroundTask() {
			guard backgroundTaskIdentifier != .invalid else {
				return
			}
			UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
			backgroundTaskIdentifier = .invalid
		}

		let syncTask = Task { @MainActor in
			await AccountManager.shared.syncArticleStatusAll()
			isSyncArticleStatusRunning = false
			endSyncBackgroundTask()
		}

		backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Sync Article Status") {
			syncTask.cancel()
			endSyncBackgroundTask()
			Self.logger.info("Accounts sync processing terminated for running too long.")
		}
	}

	func suspendApplication() {
		guard UIApplication.shared.applicationState == .background else {
			return
		}
		guard !AccountManager.shared.isSuspended else {
			return
		}

		AccountManager.shared.suspendNetworkAll()
		AccountManager.shared.saveAllIfNeeded()
		ArticleThemeDownloader.shared.cleanUp()

		AppNotification.postAppDidGoToBackground()

		CoalescingQueue.standard.performCallsImmediately()
		for scene in UIApplication.shared.connectedScenes {
			if let sceneDelegate = scene.delegate as? SceneDelegate {
				sceneDelegate.suspend()
			}
		}

		Self.logger.info("Application processing suspended.")
	}

}

// MARK: - Background Tasks

private extension AppDelegate {
	/// Register all background tasks.
	nonisolated func registerBackgroundTasks() {
		// Register background feed refresh.
		BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.ranchero.NetNewsWire.FeedRefresh", using: nil) { task in
			self.performBackgroundFeedRefresh(with: task as! BGAppRefreshTask)
		}
	}

	/// Ask the system for the next background app refresh.
	/// The actual timing is up to the system.
	nonisolated func scheduleBackgroundFeedRefresh() {
		// We send this to a dedicated serial queue because as of 11/05/19 on iOS 13.2 the call to the
		// task scheduler can hang indefinitely.
		backgroundTaskDispatchQueue.async {
			do {
				let earliestBeginInterval: TimeInterval = 60 * 60
				let request = BGAppRefreshTaskRequest(identifier: "com.ranchero.NetNewsWire.FeedRefresh")
				request.earliestBeginDate = Date(timeIntervalSinceNow: earliestBeginInterval)
				try BGTaskScheduler.shared.submit(request)
			} catch {
				Self.logger.error("Could not schedule app refresh: \(error.localizedDescription)")
			}
		}
	}

	nonisolated func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {

		scheduleBackgroundFeedRefresh() // schedule next refresh

		Self.logger.info("Performing background refresh.")

		let refreshTaskIsCompleted = OSAllocatedUnfairLock(initialState: false)

		enum RefreshOutcome {
			case completed
			case noNetwork
			case expired
		}

		/// Make sure task.setTaskCompleted is called exactly once.
		func completeRefreshTask(_ outcome: RefreshOutcome) {
			let shouldComplete = refreshTaskIsCompleted.withLock { isCompleted -> Bool in
				if isCompleted {
					return false
				}
				isCompleted = true
				return true
			}
			guard shouldComplete else {
				return
			}

			let success: Bool
			switch outcome {
			case .completed:
				Self.logger.info("Background refresh completed.")
				success = true
			case .noNetwork:
				Self.logger.info("Background refresh skipped — no network path.")
				success = false
			case .expired:
				Self.logger.info("Background refresh terminated for running too long.")
				success = false
			}

			task.setTaskCompleted(success: success)
		}

		let refreshTask = Task { @MainActor in
			if AccountManager.shared.isSuspended {
				AccountManager.shared.resumeAll()
			}
			let didRefresh = await AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
			if !Task.isCancelled {
				await WidgetDataEncoder.shared?.encodeAndWait()
			}
			self.suspendApplication()
			completeRefreshTask(didRefresh ? .completed : .noNetwork)
		}

		task.expirationHandler = {
			refreshTask.cancel()
			completeRefreshTask(.expired)
			Task { @MainActor in
				self.suspendApplication()
			}
		}
	}
}

// MARK: - Handle Notification Actions

private extension AppDelegate {
	func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
		handleStatusNotification(userInfo: userInfo, statusKey: .read)
	}

	func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
		handleStatusNotification(userInfo: userInfo, statusKey: .starred)
	}

	private func handleStatusNotification(userInfo: [AnyHashable: Any], statusKey: ArticleStatus.Key) {
		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}

		resumeIfNecessary()

		guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
			assertionFailure("Expected account with \(accountID)")
			Self.logger.error("No account with accountID \(accountID) found from status notification")
			return
		}

		Task { @MainActor in
			try? await account.markArticles(articleIDs: [articleID], statusKey: statusKey, flag: true)
			_ = try? await account.syncArticleStatus()
			prepareAccountsForBackground()
			suspendApplication()
		}
	}
}
