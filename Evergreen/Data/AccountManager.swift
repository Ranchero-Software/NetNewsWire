//
//  AccountManager.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/18/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import DataModel
import LocalAccount

let AccountsDidChangeNotification = "AccountsDidChangeNotification"

private let localAccountFolderName = "OnMyMac"
private let localAccountIdentifier = "OnMyMac"

final class AccountManager: UnreadCountProvider {

	static let sharedInstance = AccountManager()
	private let accountsFolder = RSDataSubfolder(nil, "Accounts")!
    private var accountsDictionary = [String: Account]()
	let localAccount: Account
	var unreadCount = 0 {
		didSet {
			postUnreadCountDidChangeNotification()
		}
	}

	var accounts: [Account] {
		get {
			return Array(accountsDictionary.values)
		}
	}
	var sortedAccounts: [Account] {
		get {
			return accountsSortedByName()
		}
	}

	var refreshInProgress: Bool {
		get {
			for oneAccount in accountsDictionary.values {
				if oneAccount.refreshInProgress {
					return true
				}
			}
			return false
		}
	}
	
	init() {

		// The local "On My Mac" account must always exist, even if it's empty.

		let localAccountFolder = (accountsFolder as NSString).appendingPathComponent("OnMyMac")
		do {
			try FileManager.default.createDirectory(atPath: localAccountFolder, withIntermediateDirectories: true, attributes: nil)
		}
		catch {
			assertionFailure("Could not create folder for OnMyMac account.")
			abort()
		}

		let localAccountSettingsFile = accountFilePathWithFolder(localAccountFolder)
		localAccount = LocalAccount(settingsFile: localAccountSettingsFile, dataFolder: localAccountFolder, identifier: localAccountIdentifier)
        accountsDictionary[localAccount.identifier] = localAccount

		readNonLocalAccountsFromDisk()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
	}

	// MARK: API
	
	func existingAccountWithIdentifier(_ identifier: String) -> Account? {
		
		return accountsDictionary[identifier]
	}
	
	func refreshAll() {

		accounts.forEach { (oneAccount) in
			oneAccount.refreshAll()
		}
	}

	func anyAccountHasAtLeastOneFeed() -> Bool {

		for oneAccount in accounts {
			if oneAccount.hasAtLeastOneFeed {
				return true
			}
		}

		return false
	}

	func anyAccountHasFeedWithURL(_ urlString: String) -> Bool {
		
		for oneAccount in accounts {
			if let _ = oneAccount.existingFeedWithURL(urlString) {
				return true
			}
		}
		return false
	}
	
	// MARK: UnreadCountProvider

	func updateUnreadCount() {

		let updatedUnreadCount = calculateUnreadCount(accounts)
		if updatedUnreadCount != unreadCount {
			unreadCount = updatedUnreadCount
		}
	}
	
	// MARK: Notifications
	
	dynamic func unreadCountDidChange(_ notification: Notification) {
		
		guard let _ = notification.object as? Account else {
			return
		}
		updateUnreadCount()
	}
	
	// MARK: Private

	private func createAccount(_ accountSpecifier: AccountSpecifier) -> Account? {

		return nil
	}

	private func createAccount(_ filename: String) -> Account? {

		let folderPath = (accountsFolder as NSString).appendingPathComponent(filename)
		if let accountSpecifier = AccountSpecifier(folderPath: folderPath) {
			return createAccount(accountSpecifier)
		}
		return nil
	}

	private func readNonLocalAccountsFromDisk() {

		var filenames: [String]?

		do {
			filenames = try FileManager.default.contentsOfDirectory(atPath: accountsFolder)
		}
		catch {
			print("Error reading Accounts folder: \(error)")
			return
		}

		filenames?.forEach { (oneFilename) in

			guard oneFilename != localAccountFolderName else {
				return
			}
			if let oneAccount = createAccount(oneFilename) {
				accountsDictionary[oneAccount.identifier] = oneAccount
			}
		}
	}

	private func accountsSortedByName() -> [Account] {
		
		// LocalAccount is first.
		
		return accounts.sorted { (account1, account2) -> Bool in

			if account1 === localAccount {
				return true
			}
			if account2 === localAccount {
				return false
			}

			//TODO: Use localizedCaseInsensitiveCompare:
			return account1.nameForDisplay < account2.nameForDisplay
		}
	}
}

private let accountDataFileName = "AccountData.plist"

private func accountFilePathWithFolder(_ folderPath: String) -> String {

	return NSString(string: folderPath).appendingPathComponent(accountDataFileName)
}

private struct AccountSpecifier {

	let type: String
	let identifier: String
	let folderPath: String
	let folderName: String
	let dataFilePath: String

	init?(folderPath: String) {

		self.folderPath = folderPath
		self.folderName = NSString(string: folderPath).lastPathComponent

		let nameComponents = self.folderName.components(separatedBy: "-")
		let satisfyCompilerFolderName = self.folderName
		assert(nameComponents.count == 2, "Can’t determine account info from \(satisfyCompilerFolderName)")
		if nameComponents.count != 2 {
			return nil
		}

		self.type = nameComponents[0]
		self.identifier = nameComponents[1]

		self.dataFilePath = accountFilePathWithFolder(self.folderPath)
	}
}


