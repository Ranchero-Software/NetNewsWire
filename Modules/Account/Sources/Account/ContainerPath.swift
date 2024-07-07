//
//  ContainerPath.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Used to identify the parent of an object.
// Mainly used with deleting objects and undo/redo.
// Especially redo. The idea is to put something back in the right place.

@MainActor public struct ContainerPath {

	private weak var account: Account?
	private let names: [String] // empty if top-level of account
	private let folderID: Int? // nil if top-level
	private let isTopLevel: Bool

	// folders should be from top-level down, as in ["Cats", "Tabbies"]

	public init(account: Account, folders: [Folder]) {
		self.account = account
		self.names = folders.map { $0.nameForDisplay }
		self.isTopLevel = folders.isEmpty

        self.folderID = folders.last?.folderID
	}

	public func resolveContainer() -> Container? {
		// The only time it should fail is if the account no longer exists.
		// Otherwise the worst-case scenario is that it will create Folders if needed.

		guard let account = account else {
			return nil
		}
		if isTopLevel {
			return account
		}

		if let folderID = folderID, let folder = account.existingFolder(withID: folderID) {
			return folder
		}

		return account.ensureFolder(withFolderNames: names)
	}
}
