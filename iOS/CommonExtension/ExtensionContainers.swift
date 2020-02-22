//
//  ExtensionContainers.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

protocol ExtensionContainer: ContainerIdentifiable, Codable {
	var name: String { get }
	var accountID: String { get }
}

struct ExtensionContainers: Codable {
	
	enum CodingKeys: String, CodingKey {
		case accounts
	}

	let accounts: [ExtensionAccount]
	
	var flattened: [ExtensionContainer] {
		return accounts.reduce([ExtensionContainer](), { (containers, account) in
			var result = containers
			result.append(account)
			result.append(contentsOf: account.folders)
			return result
		})
	}
	
	func findAccount(forName name: String) -> ExtensionAccount? {
		return accounts.first(where: { $0.name == name })
	}
	
}

struct ExtensionAccount: ExtensionContainer {

	enum CodingKeys: String, CodingKey {
		case name
		case accountID
		case type
		case disallowFeedInRootFolder
		case containerID
		case folders
	}

	let name: String
	let accountID: String
	let type: AccountType
	let disallowFeedInRootFolder: Bool
	let containerID: ContainerIdentifier?
	let folders: [ExtensionFolder]

	init(account: Account) {
		self.name = account.nameForDisplay
		self.accountID = account.accountID
		self.type = account.type
		self.disallowFeedInRootFolder = account.behaviors.contains(.disallowFeedInRootFolder)
		self.containerID = account.containerID
		self.folders = account.sortedFolders?.map { ExtensionFolder(folder: $0) } ?? [ExtensionFolder]()
	}

	func findFolder(forName name: String) -> ExtensionFolder? {
		return folders.first(where: { $0.name == name })
	}
	
}

struct ExtensionFolder: ExtensionContainer {

	enum CodingKeys: String, CodingKey {
		case accountName
		case accountID
		case name
		case containerID
	}

	let accountName: String
	let accountID: String
	let name: String
	let containerID: ContainerIdentifier?

	init(folder: Folder) {
		self.accountName = folder.account?.nameForDisplay ?? ""
		self.accountID = folder.account?.accountID ?? ""
		self.name = folder.nameForDisplay
		self.containerID = folder.containerID
	}
	
}
