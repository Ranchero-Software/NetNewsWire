//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import os
import RSCore
import Account
import Articles

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

	var window: UIWindow?

	private var coordinator: SceneCoordinator?
	private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Application")

	private var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				UNUserNotificationCenter.current().setBadgeCount(unreadCount)
			}
		}
	}

	// MARK: - Lifecycle

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		AppDefaults.registerDefaults()
		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			logger.info("Is first run.")
		}

		_ = AccountManager.shared

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: AccountManager.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(accountRefreshDidFinish(_:)), name: .AccountRefreshDidFinish, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidTriggerManualRefresh(_:)), name: .userDidTriggerManualRefresh, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		if isFirstRun && !AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			DefaultFeedsImporter.importDefaultFeeds(account: AccountManager.shared.defaultAccount)
		}

		BackgroundTaskManager.shared.delegate = self
		BackgroundTaskManager.shared.registerTasks()

		CacheCleaner.purgeIfNecessary()
		addHomeScreenQuickActions()

		UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { granted, _ in
			guard granted else { return }
			Task { @MainActor in
				UIApplication.shared.registerForRemoteNotifications()
			}
		}

		UNUserNotificationCenter.current().delegate = self

		_ = ArticleThemesManager.shared
		_ = UserNotificationManager.shared
		_ = ExtensionContainersFile.shared
		_ = ExtensionFeedAddRequestFile.shared
		_ = WidgetDataEncoder.shared
		_ = ArticleStatusSyncTimer.shared
		_ = FaviconDownloader.shared
		_ = FeedIconDownloader.shared

#if DEBUG
		ArticleStatusSyncTimer.shared.update()
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

			self.unreadCount = AccountManager.shared.unreadCount
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

	func applicationWillEnterForeground(_ application: UIApplication) {
		prepareAccountsForForeground()
		coordinator?.resetFocus()
	}

	private func prepareAccountsForForeground() {

		AccountManager.shared.resumeAllIfSuspended()

		ExtensionFeedAddRequestFile.shared.resume()
		ArticleStatusSyncTimer.shared.update()

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

	func applicationDidEnterBackground(_ application: UIApplication) {
		IconImageCache.shared.emptyCache()
		ArticleStringFormatter.emptyCaches()
		prepareAccountsForBackground()
	}

	private func prepareAccountsForBackground() {
		ExtensionFeedAddRequestFile.shared.suspend()
		ArticleStatusSyncTimer.shared.invalidate()
		BackgroundTaskManager.shared.scheduleBackgroundFeedRefresh()
		BackgroundTaskManager.shared.syncArticleStatus()
		WidgetDataEncoder.shared.encode()
		BackgroundTaskManager.shared.waitForSyncTasksToFinish()
	}

	func applicationWillTerminate(_ application: UIApplication) {
		ArticleStatusSyncTimer.shared.stop()
	}

	private func suspendApplication() {
		guard UIApplication.shared.applicationState == .background else { return }

		AccountManager.shared.suspendNetworkAll()
		AccountManager.shared.suspendDatabaseAll()
		ArticleThemeDownloader.shared.cleanUp()

		CoalescingQueue.standard.performCallsImmediately()
		coordinator?.suspend()
		logger.info("Application processing suspended.")
	}
}

// MARK: - Notifications

extension AppDelegate {

	@objc func unreadCountDidChange(_ note: Notification) {
		assert(Thread.isMainThread)
		assert(note.object is AccountManager)
		unreadCount = AccountManager.shared.unreadCount
	}

	@objc func accountRefreshDidFinish(_ note: Notification) {
		AppDefaults.lastRefresh = Date()
	}

	@objc func userDidTriggerManualRefresh(_ note: Notification) {

		assert(Thread.isMainThread)

		guard let errorHandler = note.userInfo?[UserInfoKey.errorHandler] as? ErrorHandlerBlock else {
			assertionFailure("Expected errorHandler in .userDidTriggerManualRefresh userInfo")
			return
		}

		coordinator?.cleanUp(conditional: true)
		AccountManager.shared.refreshAll(errorHandler: errorHandler)
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		updateUserInterfaceStyle()
	}
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate {

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

// MARK: - Home Screen Quick Actions

private extension AppDelegate {

	enum ShortcutItemType: String {
		case firstUnread = "com.ranchero.NetNewsWire.FirstUnread"
		case showSearch = "com.ranchero.NetNewsWire.ShowSearch"
		case addFeed = "com.ranchero.NetNewsWire.ShowAdd"
	}

	private func addHomeScreenQuickActions() {
		let unreadTitle = NSLocalizedString("First Unread", comment: "First Unread")
		let unreadIcon = UIApplicationShortcutIcon(systemImageName: "chevron.down.circle")
		let unreadItem = UIApplicationShortcutItem(type: ShortcutItemType.firstUnread.rawValue, localizedTitle: unreadTitle, localizedSubtitle: nil, icon: unreadIcon, userInfo: nil)

		let searchTitle = NSLocalizedString("Search", comment: "Search")
		let searchIcon = UIApplicationShortcutIcon(systemImageName: "magnifyingglass")
		let searchItem = UIApplicationShortcutItem(type: ShortcutItemType.showSearch.rawValue, localizedTitle: searchTitle, localizedSubtitle: nil, icon: searchIcon, userInfo: nil)

		let addTitle = NSLocalizedString("Add Feed", comment: "Add Feed")
		let addIcon = UIApplicationShortcutIcon(systemImageName: "plus")
		let addItem = UIApplicationShortcutItem(type: ShortcutItemType.addFeed.rawValue, localizedTitle: addTitle, localizedSubtitle: nil, icon: addIcon, userInfo: nil)

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

// MARK: - BackgroundTaskManagerDelegate

extension AppDelegate: BackgroundTaskManagerDelegate {

	func backgroundTaskManagerApplicationShouldSuspend(_: BackgroundTaskManager) {
		suspendApplication()
	}
}

// MARK: - Handle Notification Actions

private extension AppDelegate {

	func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
		handleMarked(userInfo: userInfo, statusKey: .read)
	}

	func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
		handleMarked(userInfo: userInfo, statusKey: .starred)
	}

	func handleMarked(userInfo: [AnyHashable: Any], statusKey: ArticleStatus.Key) {

		guard let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
			let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
			let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else {
				return
		}

		AccountManager.shared.resumeAllIfSuspended()

		guard let account = AccountManager.shared.existingAccount(with: accountID) else {
			logger.debug("No account found from notification with accountID \(accountID).")
			return
		}
		guard let article = try? account.fetchArticles(.articleIDs([articleID])) else {
			logger.debug("No articles found from search using \(articleID)")
			return
		}

		account.markArticles(article, statusKey: statusKey, flag: true) { _ in }
		prepareAccountsForBackground()
		account.syncArticleStatus { _ in
			if !AccountManager.shared.isSuspended {
				self.prepareAccountsForBackground()
				self.suspendApplication()
			}
		}
	}

	func handle(_ response: UNNotificationResponse) {
		AccountManager.shared.resumeAllIfSuspended()
		coordinator?.handle(response)
	}
}
