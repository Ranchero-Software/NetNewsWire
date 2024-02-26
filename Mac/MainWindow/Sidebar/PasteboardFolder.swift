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

typealias PasteboardFolderDictionary = [String: String]

struct PasteboardFolder: Hashable {
	
	private struct Key {
		static let name = "name"
		// Internal
		static let folderID = "folderID"
		static let accountID = "accountID"
	}

	
	let name: String
	let folderID: String?
	let accountID: String?
	
	init(name: String, folderID: String?, accountID: String?) {
		self.name = name
		self.folderID = folderID
		self.accountID = accountID
	}
	
	// MARK: - Reading
	
	init?(dictionary: PasteboardFolderDictionary) {
		guard let name = dictionary[Key.name] else {
			return nil
		}
		
		let folderID = dictionary[Key.folderID]
		let accountID = dictionary[Key.accountID]
		
		self.init(name: name, folderID: folderID, accountID: accountID)
	}
	
	init?(pasteboardItem: NSPasteboardItem) {
		var pasteboardType: NSPasteboard.PasteboardType?
		if pasteboardItem.types.contains(FolderPasteboardWriter.folderUTIInternalType) {
			pasteboardType = FolderPasteboardWriter.folderUTIInternalType
		}

		if let foundType = pasteboardType {
			if let folderDictionary = pasteboardItem.propertyList(forType: foundType) as? PasteboardFeedDictionary {
				self.init(dictionary: folderDictionary)
				return
			}
		}
		
		return nil
	}
	
	static func pasteboardFolders(with pasteboard: NSPasteboard) -> Set<PasteboardFolder>? {
		guard let items = pasteboard.pasteboardItems else {
			return nil
		}
		let folders = items.compactMap { PasteboardFolder(pasteboardItem: $0) }
		return folders.isEmpty ? nil : Set(folders)
	}
	
	// MARK: - Writing
	
	func internalDictionary() -> PasteboardFolderDictionary {
		var d = PasteboardFeedDictionary()
		d[PasteboardFolder.Key.name] = name
		if let folderID = folderID {
			d[PasteboardFolder.Key.folderID] = folderID
		}
		if let accountID = accountID {
			d[PasteboardFolder.Key.accountID] = accountID
		}
		return d
	}
}

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
			plist = internalDictionary
		default:
			plist = nil
		}

		return plist
	}
}

private extension FolderPasteboardWriter {
	var pasteboardFolder: PasteboardFolder {
		return PasteboardFolder(name: folder.name ?? "", folderID: String(folder.folderID), accountID: folder.account?.accountID)
	}
	
	var internalDictionary: PasteboardFeedDictionary {
		return pasteboardFolder.internalDictionary()
	}
}
