//
//  ShareDefaultContainer.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor struct ShareDefaultContainer {

	private static let addFeedAccountIDKey = "addFeedAccountID"
	private static let addFeedFolderNameKey = "addFeedFolderName"

	static func defaultContainer(containers: ExtensionContainers) -> ExtensionContainer? {

		if let accountID = UserDefaults.standard.string(forKey: addFeedAccountIDKey), let account = containers.accounts.first(where: { $0.accountID == accountID }) {
			if let folderName = UserDefaults.standard.string(forKey: addFeedFolderNameKey), let folder = account.folders.first(where: { $0.name == folderName }) {
				return folder
			} else {
				return substituteContainerIfNeeded(account: account)
			}
		} else if let account = containers.accounts.first {
			return substituteContainerIfNeeded(account: account)
		} else {
			return nil
		}

	}

	static func saveDefaultContainer(_ container: ExtensionContainer) {
		UserDefaults.standard.set(container.accountID, forKey: addFeedAccountIDKey)
		if let folder = container as? ExtensionFolder {
			UserDefaults.standard.set(folder.name, forKey: addFeedFolderNameKey)
		} else {
			UserDefaults.standard.removeObject(forKey: addFeedFolderNameKey)
		}
	}

	private static func substituteContainerIfNeeded(account: ExtensionAccount) -> ExtensionContainer? {
		if !account.disallowFeedInRootFolder {
			return account
		} else {
			if let folder = account.folders.first {
				return folder
			} else {
				return nil
			}
		}
	}
}
