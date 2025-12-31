//
//  AccountManager.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/18/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore
import RSWeb
import Articles
import ArticlesDatabase
import RSDatabase

@MainActor public final class AccountManager: UnreadCountProvider {
	public static var shared = AccountManager()

	public static let netNewsWireNewsURL = "https://netnewswire.blog/feed.xml"
    private static let jsonNetNewsWireNewsURL = "https://netnewswire.blog/feed.json"

	public let defaultAccount: Account

	private let accountsFolder: String
    private var accountsDictionary = [String: Account]()

	private let defaultAccountFolderName = "OnMyMac"
	private let defaultAccountIdentifier = "OnMyMac"

	public var isSuspended = false

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountManager")

	public var areUnreadCountsInitialized: Bool {
		for account in activeAccounts {
			if !account.areUnreadCountsInitialized {
				return false
			}
		}
		return true
	}

	public var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	public var accounts: [Account] {
		Array(accountsDictionary.values)
	}

	public var sortedAccounts: [Account] {
		sortByName(accounts)
	}

	public var hasiCloudAccount: Bool {
		for account in accounts {
			if account.type == .cloudKit {
				return true
			}
		}
		return false
	}


	public var activeAccounts: [Account] {
		assert(Thread.isMainThread)
		return Array(accountsDictionary.values.filter { $0.isActive })
	}

	public var sortedActiveAccounts: [Account] {
		sortByName(activeAccounts)
	}

	public var lastArticleFetchEndTime: Date? {
		var lastArticleFetchEndTime: Date? = nil
		for account in activeAccounts {
			if let accountLastArticleFetchEndTime = account.metadata.lastArticleFetchEndTime {
				if lastArticleFetchEndTime == nil || lastArticleFetchEndTime! < accountLastArticleFetchEndTime {
					lastArticleFetchEndTime = accountLastArticleFetchEndTime
				}
			}
		}
		return lastArticleFetchEndTime
	}

	public func existingActiveAccount(forDisplayName displayName: String) -> Account? {
		AccountManager.shared.activeAccounts.first(where: { $0.nameForDisplay == displayName })
	}

	public var refreshInProgress: Bool {
		for account in activeAccounts {
			if account.refreshInProgress {
				return true
			}
		}
		return false
	}

	public let combinedRefreshProgress = CombinedRefreshProgress()

	private var isActive = false

	public init() {
		self.accountsFolder = AppConfig.dataSubfolder(named: "Accounts").path

		// The local "On My Mac" account must always exist, even if it's empty.
		let localAccountFolder = (accountsFolder as NSString).appendingPathComponent("OnMyMac")
		do {
			try FileManager.default.createDirectory(atPath: localAccountFolder, withIntermediateDirectories: true, attributes: nil)
		}
		catch {
			assertionFailure("Could not create folder for OnMyMac account.")
			abort()
		}

		defaultAccount = Account(dataFolder: localAccountFolder, type: .onMyMac, accountID: defaultAccountIdentifier)
        accountsDictionary[defaultAccount.accountID] = defaultAccount

		readAccountsFromDisk()
	}

	public func start() {
		guard !isActive else {
			assertionFailure("start called when isActive is already true")
			return
		}
		isActive = true

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateUnreadCount()
		}
	}

	// MARK: - API

	public func createAccount(type: AccountType) -> Account {
		if type == .cloudKit {
			if let existingiCloudAccount = accounts.first(where: { $0.type == .cloudKit }) {
				return existingiCloudAccount
			}
		}

		let accountID = type == .cloudKit ? "iCloud" : UUID().uuidString
		let accountFolder = (accountsFolder as NSString).appendingPathComponent("\(type.rawValue)_\(accountID)")

		do {
			try FileManager.default.createDirectory(atPath: accountFolder, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for \(accountID) account.")
			abort()
		}

		let account = Account(dataFolder: accountFolder, type: type, accountID: accountID)
		accountsDictionary[accountID] = account

		var userInfo = [String: Any]()
		userInfo[Account.UserInfoKey.account] = account
		NotificationCenter.default.post(name: .UserDidAddAccount, object: self, userInfo: userInfo)

		return account
	}

	public func deleteAccount(_ account: Account) {
		guard !account.refreshInProgress else {
			return
		}

		account.prepareForDeletion()

		accountsDictionary.removeValue(forKey: account.accountID)
		account.isDeleted = true

		do {
			try FileManager.default.removeItem(atPath: account.dataFolder)
		}
		catch let error as CocoaError where error.code == .fileNoSuchFile {
			// Already doesn’t exist.
		}
		catch {
			// TODO: add logging and/or reporting to user. No need to crash here.
		}

		updateUnreadCount()

		var userInfo = [String: Any]()
		userInfo[Account.UserInfoKey.account] = account
		NotificationCenter.default.post(name: .UserDidDeleteAccount, object: self, userInfo: userInfo)
	}

	public func duplicateServiceAccount(type: AccountType, username: String?) -> Bool {
		guard type != .onMyMac else {
			return false
		}
		for account in accounts {
			if account.type == type && username == account.username {
				return true
			}
		}
		return false
	}

	public func existingAccount(accountID: String) -> Account? {
		return accountsDictionary[accountID]
	}

	public func existingContainer(with containerID: ContainerIdentifier) -> Container? {
		switch containerID {
		case .account(let accountID):
			return existingAccount(accountID: accountID)
		case .folder(let accountID, let folderName):
			return existingAccount(accountID: accountID)?.existingFolder(with: folderName)
		default:
			break
		}
		return nil
	}

	public func existingFeed(with sidebarItemID: SidebarItemIdentifier) -> SidebarItem? {
		switch sidebarItemID {
		case .folder(let accountID, let folderName):
			if let account = existingAccount(accountID: accountID) {
				return account.existingFolder(with: folderName)
			}
		case .feed(let accountID, let feedID):
			if let account = existingAccount(accountID: accountID) {
				return account.existingFeed(withFeedID: feedID)
			}
		default:
			break
		}
		return nil
	}

	public func suspendNetworkAll() {
		isSuspended = true
		for account in accounts {
			account.suspendNetwork()
		}
	}

	public func suspendDatabaseAll() {
		for account in accounts {
			account.suspendDatabase()
		}
	}

	public func resumeAll() {
		isSuspended = false
		for account in accounts {
			account.resumeDatabaseAndDelegate()
		}
		for account in accounts {
			account.resume()
		}
	}

	public func receiveRemoteNotification(userInfo: [AnyHashable : Any]) async {
		Task {
			for account in activeAccounts {
				await account.receiveRemoteNotification(userInfo: userInfo)
			}
		}
	}

	public typealias ErrorHandlerCallback = @Sendable (Error) -> Void

	public func refreshAllWithoutWaiting(errorHandler: ErrorHandlerCallback? = nil) {
		Task {
			await refreshAll(errorHandler: errorHandler)
		}
	}

	public func refreshAll(errorHandler: ErrorHandlerCallback? = nil) async {
		guard NetworkMonitor.shared.isConnected else {
			Self.logger.info("AccountManager: skipping refreshAll — not connected to internet.")
			return
		}

		combinedRefreshProgress.start()
		defer {
			combinedRefreshProgress.stop()
		}

		await withTaskGroup(of: Void.self, isolation: MainActor.shared) { group in
			for account in activeAccounts {
				group.addTask {
					do {
						try await account.refreshAll()
					} catch {
						errorHandler?(error)
					}
				}
			}
		}
	}

	public func sendArticleStatusAll() async {
		await withTaskGroup(of: Void.self, isolation: MainActor.shared) { group in
			for account in activeAccounts {
				group.addTask {
					try? await account.sendArticleStatus()
				}
			}
		}
	}

	public func syncArticleStatusAllWithoutWaiting() {
		Task {
			await syncArticleStatusAll()
		}
	}

	public func syncArticleStatusAll() async {
		await withTaskGroup(of: Void.self, isolation: MainActor.shared) { group in
			for account in activeAccounts {
				group.addTask {
					try? await account.syncArticleStatus()
				}
			}
		}
	}

	public func saveAll() {
		for account in accounts {
			account.save()
		}
	}

	public func anyAccountHasAtLeastOneFeed() -> Bool {
		for account in activeAccounts {
			if account.hasAtLeastOneFeed() {
				return true
			}
		}

		return false
	}

	public func anyAccountHasNetNewsWireNewsSubscription() -> Bool {
		anyAccountHasFeedWithURL(Self.netNewsWireNewsURL) || anyAccountHasFeedWithURL(Self.jsonNetNewsWireNewsURL)
	}

	public func anyAccountHasFeedWithURL(_ urlString: String) -> Bool {
		for account in activeAccounts {
			if let _ = account.existingFeed(withURL: urlString) {
				return true
			}
		}
		return false
	}

	// MARK: - Fetching Articles

	// These fetch articles from active accounts and return a merged Set<Article>.

	public func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
		precondition(Thread.isMainThread)

		var articles = Set<Article>()
		for account in activeAccounts {
			articles.formUnion(try account.fetchArticles(fetchType))
		}
		return articles
	}

	public func fetchArticlesAsync(_ fetchType: FetchType) async throws -> Set<Article> {
		precondition(Thread.isMainThread)

		guard activeAccounts.count > 0 else {
			return Set<Article>()
		}

		var allFetchedArticles = Set<Article>()
		for account in activeAccounts {
			let articles = try await account.fetchArticlesAsync(fetchType)
			allFetchedArticles.formUnion(articles)
		}

		return allFetchedArticles
	}

	/// Fetch a single article (synchronously) by accountID and articleID.
	public func fetchArticle(accountID: String, articleID: String) -> Article? {
		precondition(Thread.isMainThread)

		guard let account = existingAccount(accountID: accountID) else {
			return nil
		}

		do {
			let articles = try account.fetchArticles(.articleIDs(Set([articleID])))
			return articles.first
		} catch {
			return nil
		}
	}

	// MARK: - Fetching Article Counts

	public func fetchCountForStarredArticles() throws -> Int {
		precondition(Thread.isMainThread)
		var count = 0
		for account in activeAccounts {
			count += try account.fetchCountForStarredArticles()
		}
		return count
	}

	// MARK: - Caches

	/// Empty caches that can reasonably be emptied — when the app moves to the background, for instance.
	public func emptyCaches() {
		for account in accounts {
			account.emptyCaches()
		}
	}

	// MARK: - Notifications

	@objc func unreadCountDidInitialize(_ notification: Notification) {
		guard notification.object is Account else {
			return
		}
		if areUnreadCountsInitialized {
			postUnreadCountDidInitializeNotification()
		}
	}

	@objc func unreadCountDidChange(_ notification: Notification) {
		guard notification.object is Account else {
			return
		}
		updateUnreadCount()
	}

	@objc func accountStateDidChange(_ notification: Notification) {
		updateUnreadCount()
	}
}

// MARK: - Private

private extension AccountManager {

	func updateUnreadCount() {
		unreadCount = calculateUnreadCount(activeAccounts)
	}

	func loadAccount(_ accountSpecifier: AccountSpecifier) -> Account? {
		Account(dataFolder: accountSpecifier.folderPath, type: accountSpecifier.type, accountID: accountSpecifier.identifier)
	}

	func loadAccount(_ filename: String) -> Account? {
		let folderPath = (accountsFolder as NSString).appendingPathComponent(filename)
		if let accountSpecifier = AccountSpecifier(folderPath: folderPath) {
			return loadAccount(accountSpecifier)
		}
		return nil
	}

	func readAccountsFromDisk() {
		var filenames: [String]?

		do {
			filenames = try FileManager.default.contentsOfDirectory(atPath: accountsFolder)
		}
		catch {
			print("Error reading Accounts folder: \(error)")
			return
		}

		guard let filenames = filenames?.sorted() else {
			return
		}

		for oneFilename in filenames {
			guard oneFilename != defaultAccountFolderName else {
				continue
			}
			if let oneAccount = loadAccount(oneFilename) {
				if !duplicateServiceAccount(oneAccount) {
					accountsDictionary[oneAccount.accountID] = oneAccount
				}
			}
		}
	}

	func duplicateServiceAccount(_ account: Account) -> Bool {
		duplicateServiceAccount(type: account.type, username: account.username)
	}

	func sortByName(_ accounts: [Account]) -> [Account] {
		// LocalAccount is first.

		return accounts.sorted { (account1, account2) -> Bool in
			if account1 === defaultAccount {
				return true
			}
			if account2 === defaultAccount {
				return false
			}
			return (account1.nameForDisplay as NSString).localizedStandardCompare(account2.nameForDisplay) == .orderedAscending
		}
	}
}

private struct AccountSpecifier {

	let type: AccountType
	let identifier: String
	let folderPath: String
	let folderName: String
	let dataFilePath: String

	init?(folderPath: String) {
		if !FileManager.default.isFolder(atPath: folderPath) {
			return nil
		}

		let name = NSString(string: folderPath).lastPathComponent
		if name.hasPrefix(".") {
			return nil
		}

		let nameComponents = name.components(separatedBy: "_")

		guard nameComponents.count == 2, let rawType = Int(nameComponents[0]), let accountType = AccountType(rawValue: rawType) else {
			return nil
		}

		self.folderPath = folderPath
		self.folderName = name
		self.type = accountType
		self.identifier = nameComponents[1]

		self.dataFilePath = AccountSpecifier.accountFilePathWithFolder(self.folderPath)
	}

	private static let accountDataFileName = "AccountData.plist"

	private static func accountFilePathWithFolder(_ folderPath: String) -> String {
		return NSString(string: folderPath).appendingPathComponent(accountDataFileName)
	}
}
