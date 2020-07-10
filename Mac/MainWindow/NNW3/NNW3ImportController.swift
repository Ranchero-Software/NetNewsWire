//
//  NNW3ImportController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

struct NNW3ImportController {

	/// Import NNW3 subscriptions if they exist.
	/// Return true if Subscriptions.plist was found and subscriptions were imported.
	static func importSubscriptionsIfFileExists(account: Account) -> Bool {
		guard let subscriptionsPlistURL = defaultFileURL else {
			return false
		}
		if !FileManager.default.fileExists(atPath: subscriptionsPlistURL.path) {
			return false
		}
		NNW3ImportController.importSubscriptionsPlist(subscriptionsPlistURL, into: account)
		return true
		}

	/// Run an NSOpenPanel and import subscriptions (if the user chooses to).
	static func askUserToImportNNW3Subscriptions(window: NSWindow) {
		chooseFile(window)
	}
}

private extension NNW3ImportController {

	/// URL to ~/Library/Application Support/NetNewsWire/Subscriptions.plist
	static var defaultFileURL: URL? {
		guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
			return nil
		}
		let folderURL = applicationSupportURL.appendingPathComponent("NetNewsWire", isDirectory: true)
		return folderURL.appendingPathComponent("Subscriptions.plist", isDirectory: false)
	}

	/// Import Subscriptions.plist file. Convert to OPML and then import into specified Account.
	static func importSubscriptionsPlist(_ subscriptionsPlistURL: URL, into account: Account) {
		guard let opmlURL = convertToOPMLFile(subscriptionsPlistURL: subscriptionsPlistURL) else {
			return
		}
		account.importOPML(opmlURL) { result in
			try? FileManager.default.removeItem(at: opmlURL)
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}

	/// Run the NSOpenPanel. On success, import subscriptions to the selected account.
	static func chooseFile(_ window: NSWindow) {
		let accessoryViewController = NNW3OpenPanelAccessoryViewController()

		let panel = NSOpenPanel()
		panel.canDownloadUbiquitousContents = true
		panel.canResolveUbiquitousConflicts = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.resolvesAliases = true
		panel.directoryURL = NNW3ImportController.defaultFileURL
		panel.allowedFileTypes = ["plist"]
		panel.allowsOtherFileTypes = false
		panel.accessoryView = accessoryViewController.view
		panel.isAccessoryViewDisclosed = true
		panel.title = NSLocalizedString("Choose a Subscriptions.plist file:", comment: "NNW3 Import")
		
		panel.beginSheetModal(for: window) { modalResult in
			guard modalResult == .OK, let subscriptionsPlistURL = panel.url else {
				return
			}
			guard let account = accessoryViewController.selectedAccount else {
				return
			}
			AppDefaults.shared.importOPMLAccountID = account.accountID

			NNW3ImportController.importSubscriptionsPlist(subscriptionsPlistURL, into: account)
		}
	}

	/// Convert Subscriptions.plist on disk to a temporary OPML file.
	static func convertToOPMLFile(subscriptionsPlistURL url: URL) -> URL? {
		guard let document = NNW3Document(subscriptionsPlistURL: url) else {
			return nil
		}
		let opml = document.OPMLString(indentLevel: 0)

		let opmlURL = FileManager.default.temporaryDirectory.appendingPathComponent("NNW3.opml")
		do {
			try opml.write(to: opmlURL, atomically: true, encoding: .utf8)
		} catch let error as NSError {
			NSApplication.shared.presentError(error)
			return nil
		}

		return opmlURL
	}
}
