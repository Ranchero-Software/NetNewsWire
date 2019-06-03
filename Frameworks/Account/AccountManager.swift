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

public extension Notification.Name {
	static let AccountsDidChange = Notification.Name(rawValue: "AccountsDidChange")
}

private let defaultAccountFolderName = "OnMyMac"
private let defaultAccountIdentifier = "OnMyMac"

public final class AccountManager: UnreadCountProvider {

	public static let shared = AccountManager()
	public let defaultAccount: Account

	private let accountsFolder = RSDataSubfolder(nil, "Accounts")!
    private var accountsDictionary = [String: Account]()

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
		return Array(accountsDictionary.values.filter { $0.isActive })
	}

	public var sortedActiveAccounts: [Account] {
		return sortByName(activeAccounts)
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
	
	public init() {
		
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

	// MARK: API
	
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
		
		NotificationCenter.default.post(name: .AccountsDidChange, object: self)
		
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
		NotificationCenter.default.post(name: .AccountsDidChange, object: self)
		
	}
	
	public func existingAccount(with accountID: String) -> Account? {
		
		return accountsDictionary[accountID]
	}
	
	public func refreshAll(errorHandler: @escaping (Error) -> Void) {

		activeAccounts.forEach { account in
			account.refreshAll() { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					errorHandler(error)
				}
			}
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

		group.notify(queue: DispatchQueue.main) {
			completion?()
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

	public func anyAccountHasFeedWithURL(_ urlString: String) -> Bool {
		
		for account in activeAccounts {
			if let _ = account.existingFeed(withURL: urlString) {
				return true
			}
		}
		return false
	}
	
	func updateUnreadCount() {

		unreadCount = calculateUnreadCount(activeAccounts)
	}
	
	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		
		guard let _ = notification.object as? Account else {
			return
		}
		updateUnreadCount()
	}
	
	@objc func accountStateDidChange(_ notification: Notification) {
		updateUnreadCount()
	}
	
	// MARK: Private

	private func loadAccount(_ accountSpecifier: AccountSpecifier) -> Account? {
		return Account(dataFolder: accountSpecifier.folderPath, type: accountSpecifier.type, accountID: accountSpecifier.identifier)
	}

	private func loadAccount(_ filename: String) -> Account? {

		let folderPath = (accountsFolder as NSString).appendingPathComponent(filename)
		if let accountSpecifier = AccountSpecifier(folderPath: folderPath) {
			return loadAccount(accountSpecifier)
		}
		return nil
	}

	private func readAccountsFromDisk() {

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

	private func sortByName(_ accounts: [Account]) -> [Account] {
		
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

private let accountDataFileName = "AccountData.plist"

private func accountFilePathWithFolder(_ folderPath: String) -> String {

	return NSString(string: folderPath).appendingPathComponent(accountDataFileName)
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
		
		guard nameComponents.count == 2, let rawType = Int(nameComponents[0]), let acctType = AccountType(rawValue: rawType) else {
			return nil
		}

		self.folderPath = folderPath
		self.folderName = name
		self.type = acctType
		self.identifier = nameComponents[1]

		self.dataFilePath = accountFilePathWithFolder(self.folderPath)
		
	}
}


