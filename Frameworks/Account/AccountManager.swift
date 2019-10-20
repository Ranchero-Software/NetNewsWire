//
//  AccountManager.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/18/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles

// Main thread only.

public final class AccountManager: UnreadCountProvider {

	public static var shared: AccountManager!
	
	public let defaultAccount: Account

	private let accountsFolder: String
    private var accountsDictionary = [String: Account]()

	private let defaultAccountFolderName = "OnMyMac"
	private let defaultAccountIdentifier = "OnMyMac"

	public var isUnreadCountsInitialized: Bool {
		for account in activeAccounts {
			if !account.isUnreadCountsInitialized {
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
		return Array(accountsDictionary.values)
	}

	public var sortedAccounts: [Account] {
		return sortByName(accounts)
	}

	public var activeAccounts: [Account] {
		assert(Thread.isMainThread)
		return Array(accountsDictionary.values.filter { $0.isActive })
	}

	public var sortedActiveAccounts: [Account] {
		return sortByName(activeAccounts)
	}

	public func findActiveAccount(forDisplayName displayName: String) -> Account? {
		return AccountManager.shared.activeAccounts.first(where: { $0.nameForDisplay == displayName })
	}
	
	public var refreshInProgress: Bool {
		for account in activeAccounts {
			if account.refreshInProgress {
				return true
			}
		}
		return false
	}
	
	public var combinedRefreshProgress: CombinedRefreshProgress {
		let downloadProgressArray = activeAccounts.map { $0.refreshProgress }
		return CombinedRefreshProgress(downloadProgressArray: downloadProgressArray)
	}
	
	public convenience init() {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let accountsURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		let accountsFolder = accountsURL!.appendingPathComponent("Accounts").absoluteString
		let accountsFolderPath = accountsFolder.suffix(from: accountsFolder.index(accountsFolder.startIndex, offsetBy: 7))
		self.init(accountsFolder: String(accountsFolderPath))
	}
	
	public init(accountsFolder: String) {
		self.accountsFolder = accountsFolder
		
		// The local "On My Mac" account must always exist, even if it's empty.
		let localAccountFolder = (accountsFolder as NSString).appendingPathComponent("OnMyMac")
		do {
			try FileManager.default.createDirectory(atPath: localAccountFolder, withIntermediateDirectories: true, attributes: nil)
		}
		catch {
			assertionFailure("Could not create folder for OnMyMac account.")
			abort()
		}

		defaultAccount = Account(dataFolder: localAccountFolder, type: .onMyMac, accountID: defaultAccountIdentifier)!
        accountsDictionary[defaultAccount.accountID] = defaultAccount

		readAccountsFromDisk()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)

		DispatchQueue.main.async {
			self.updateUnreadCount()
		}
	}

	// MARK: - API
	
	public func createAccount(type: AccountType) -> Account {
		let accountID = UUID().uuidString
		let accountFolder = (accountsFolder as NSString).appendingPathComponent("\(type.rawValue)_\(accountID)")

		do {
			try FileManager.default.createDirectory(atPath: accountFolder, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for \(accountID) account.")
			abort()
		}
		
		let account = Account(dataFolder: accountFolder, type: type, accountID: accountID)!
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
		
		accountsDictionary.removeValue(forKey: account.accountID)
		account.isDeleted = true
		
		do {
			try FileManager.default.removeItem(atPath: account.dataFolder)
		}
		catch {
			assertionFailure("Could not create folder for OnMyMac account.")
			abort()
		}
		
		updateUnreadCount()

		var userInfo = [String: Any]()
		userInfo[Account.UserInfoKey.account] = account
		NotificationCenter.default.post(name: .UserDidDeleteAccount, object: self, userInfo: userInfo)
	}
	
	public func existingAccount(with accountID: String) -> Account? {
		return accountsDictionary[accountID]
	}
	
	public func refreshAll(errorHandler: @escaping (Error) -> Void, completion: (() ->Void)? = nil) {
		let group = DispatchGroup()
		
		activeAccounts.forEach { account in
			group.enter()
			account.refreshAll() { result in
				group.leave()
				switch result {
				case .success:
					break
				case .failure(let error):
					errorHandler(error)
				}
			}
		}
		
		group.notify(queue: DispatchQueue.main) {
			completion?()
		}
		
	}

	public func syncArticleStatusAll(completion: (() -> Void)? = nil) {
		let group = DispatchGroup()
		
		activeAccounts.forEach {
			group.enter()
			$0.syncArticleStatus() {
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.global(qos: .background)) {
			completion?()
		}
	}
	
	public func saveAll() {
		accounts.forEach { $0.save() }
	}
	
	public func anyAccountHasAtLeastOneFeed() -> Bool {
		for account in activeAccounts {
			if account.hasAtLeastOneFeed() {
				return true
			}
		}

		return false
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

	public func fetchArticles(_ fetchType: FetchType) ->  Set<Article> {
		precondition(Thread.isMainThread)

		var articles = Set<Article>()
		for account in activeAccounts {
			articles.formUnion(account.fetchArticles(fetchType))
		}
		return articles
	}

	public func fetchArticlesAsync(_ fetchType: FetchType, _ callback: @escaping ArticleSetBlock) {
		precondition(Thread.isMainThread)
		
		var allFetchedArticles = Set<Article>()
		let numberOfAccounts = activeAccounts.count
		var accountsReporting = 0

		for account in activeAccounts {
			account.fetchArticlesAsync(fetchType) { (articles) in
				allFetchedArticles.formUnion(articles)
				accountsReporting += 1
				if accountsReporting == numberOfAccounts {
					callback(allFetchedArticles)
				}
			}
		}
	}

	// MARK: - Caches

	/// Empty caches that can reasonably be emptied — when the app moves to the background, for instance.
	public func emptyCaches() {
		for account in accounts {
			account.emptyCaches()
		}
	}

	// MARK: - Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		guard let _ = notification.object as? Account else {
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
		return Account(dataFolder: accountSpecifier.folderPath, type: accountSpecifier.type, accountID: accountSpecifier.identifier)
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

		filenames?.forEach { (oneFilename) in
			guard oneFilename != defaultAccountFolderName else {
				return
			}
			if let oneAccount = loadAccount(oneFilename) {
				accountsDictionary[oneAccount.accountID] = oneAccount
			}
		}
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
		if !FileManager.default.rs_fileIsFolder(folderPath) {
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
