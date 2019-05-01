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
	static let AccountsDidChangeNotification = Notification.Name(rawValue: "AccountsDidChangeNotification")
}

private let defaultAccountFolderName = "OnMyMac"
private let defaultAccountIdentifier = "OnMyMac"

public final class AccountManager: UnreadCountProvider {

	public static let shared = AccountManager()
	public let defaultAccount: Account
	private let accountsFolder = RSDataSubfolder(nil, "Accounts")!
    private var accountsDictionary = [String: Account]()

	public var isUnreadCountsInitialized: Bool {
		for account in accounts {
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
		return accountsSortedByName()
	}

	public var refreshInProgress: Bool {
		for account in accounts {
			if account.refreshInProgress {
				return true
			}
		}
		return false
	}
	
	public var combinedRefreshProgress: CombinedRefreshProgress {
		let downloadProgressArray = accounts.map { $0.refreshProgress }
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
		
		DispatchQueue.main.async {
			self.updateUnreadCount()
		}
	}

	// MARK: API
	
	public func createAccount(type: AccountType, username: String? = nil, password: String? = nil) -> Account {
		
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
		
		NotificationCenter.default.post(name: .AccountsDidChangeNotification, object: self)
		
		return account
	}
	
	public func existingAccount(with accountID: String) -> Account? {
		
		return accountsDictionary[accountID]
	}
	
	public func refreshAll() {

		accounts.forEach { $0.refreshAll() }
	}

	public func anyAccountHasAtLeastOneFeed() -> Bool {

		for account in accounts {
			if account.hasAtLeastOneFeed() {
				return true
			}
		}

		return false
	}

	public func anyAccountHasFeedWithURL(_ urlString: String) -> Bool {
		
		for account in accounts {
			if let _ = account.existingFeed(withURL: urlString) {
				return true
			}
		}
		return false
	}
	
	func updateUnreadCount() {

		unreadCount = calculateUnreadCount(accounts)
	}
	
	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		
		guard let _ = notification.object as? Account else {
			return
		}
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

	private func accountsSortedByName() -> [Account] {
		
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


