//
//  ExtensionContainersFile.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import Account

final class ExtensionContainersFile: Logging {
	
	private static var filePath: String = {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		return containerURL!.appendingPathComponent("extension_containers.plist").path
	}()
	
	private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}
	private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)

	init() {
		if !FileManager.default.fileExists(atPath: ExtensionContainersFile.filePath) {
			save()
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(markAsDirty), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(markAsDirty), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(markAsDirty), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(markAsDirty), name: .ChildrenDidChange, object: nil)
	}

	/// Reads and decodes the shared plist file.
	static func read() -> ExtensionContainers? {
		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator()
		let fileURL = URL(fileURLWithPath: ExtensionContainersFile.filePath)
		var extensionContainers: ExtensionContainers? = nil

		fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { readURL in
			if let fileData = try? Data(contentsOf: readURL) {
				let decoder = PropertyListDecoder()
				extensionContainers = try? decoder.decode(ExtensionContainers.self, from: fileData)
			}
		})
		
		if let error = errorPointer?.pointee {
			logger.error("Read from coordination failed: \(error.localizedDescription, privacy: .public)")
		}

		return extensionContainers
	}
	
}

private extension ExtensionContainersFile {

	@objc func markAsDirty() {
		isDirty = true
	}
	
	func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}

	func save() {
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator()
		let fileURL = URL(fileURLWithPath: ExtensionContainersFile.filePath)
		
		fileCoordinator.coordinate(writingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { [weak self] writeURL in
			do {
				let extensionAccounts = AccountManager.shared.sortedActiveAccounts.map { ExtensionAccount(account: $0) }
				let extensionContainers = ExtensionContainers(accounts: extensionAccounts)
				let data = try encoder.encode(extensionContainers)
				try data.write(to: writeURL)
			} catch let error as NSError {
				self?.logger.error("Save to disk failed: \(error.localizedDescription, privacy: .public)")
			}
		})
		
		if let error = errorPointer?.pointee {
			logger.error("Save to disk coordination failed: \(error.localizedDescription, privacy: .public)")
		}
	}

}
