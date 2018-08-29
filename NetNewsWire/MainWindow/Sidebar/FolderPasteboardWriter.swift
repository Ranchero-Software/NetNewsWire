//
//  FolderPasteboardWriter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

extension Folder: PasteboardWriterOwner {

	public var pasteboardWriter: NSPasteboardWriting {
		return FolderPasteboardWriter(folder: self)
	}
}

@objc final class FolderPasteboardWriter: NSObject, NSPasteboardWriting {

	private let folder: Folder
	static let folderUTIInternal = "com.ranchero.NetNewsWire-Evergreen.internal.folder"
	static let folderUTIInternalType = NSPasteboard.PasteboardType(rawValue: folderUTIInternal)

	init(folder: Folder) {

		self.folder = folder
	}

	// MARK: - NSPasteboardWriting

	func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {

		return [.string, FolderPasteboardWriter.folderUTIInternalType]
	}

	func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {

		let plist: Any?

		switch type {
		case .string:
			plist = folder.nameForDisplay
		case FolderPasteboardWriter.folderUTIInternalType:
			plist = internalDictionary()
		default:
			plist = nil
		}

		return plist
	}
}

private extension FolderPasteboardWriter {

	private struct Key {

		static let name = "name"

		// Internal
		static let accountID = "accountID"
		static let folderID = "folderID"
	}

	func internalDictionary() -> [String: Any] {

		var d = [String: Any]()

		d[Key.folderID] = folder.folderID
		if let name = folder.name {
			d[Key.name] = name
		}
		if let accountID = folder.account?.accountID {
			d[Key.accountID] = accountID
		}

		return d

	}
}

