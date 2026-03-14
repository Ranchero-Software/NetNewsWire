//
//  AccountsDetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class AccountsDetailViewController: NSViewController, NSTextFieldDelegate {
	@IBOutlet var typeLabel: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var activeButton: NSButtonCell!
	@IBOutlet var credentialsButton: NSButton!
	@IBOutlet var storagePathLabel: NSTextField!
	@IBOutlet var storagePathTextField: NSTextField!
	@IBOutlet var changePathButton: NSButton!

	private var accountsWindowController: NSWindowController?
	private var account: Account?

	init(account: Account) {
		super.init(nibName: "AccountsDetail", bundle: nil)
		self.account = account
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	private var hidesCredentialsButton: Bool {
		guard let account = account else {
			return true
		}
		switch account.type {
		case .onMyMac, .cloudKit, .feedly:
			return true
		default:
			return false
		}
	}

	private var isOnMyMacAccount: Bool {
		return account?.type == .onMyMac
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		nameTextField.delegate = self
		typeLabel.stringValue = account?.defaultName ?? ""
		nameTextField.stringValue = account?.name ?? ""
		activeButton.state = account?.isActive ?? false ? .on : .off
		credentialsButton.isHidden = hidesCredentialsButton

		updateStoragePathUI()
	}

	private func updateStoragePathUI() {
		let showStoragePath = isOnMyMacAccount
		storagePathLabel?.isHidden = !showStoragePath
		storagePathTextField?.isHidden = !showStoragePath
		changePathButton?.isHidden = !showStoragePath

		if showStoragePath, let account = account {
			storagePathTextField?.stringValue = account.dataFolder
			storagePathTextField?.toolTip = account.dataFolder
		}
	}

	func controlTextDidEndEditing(_ obj: Notification) {
		if !nameTextField.stringValue.isEmpty {
			account?.name = nameTextField.stringValue
		} else {
			account?.name = nil
		}
	}

	@IBAction func active(_ sender: NSButtonCell) {
		account?.isActive = sender.state == .on ? true : false
	}

	@IBAction func credentials(_ sender: Any) {
		guard let account else {
			return
		}
		guard let window = view.window else {
			return
		}

		switch account.type {
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsWindowController = accountsFeedbinWindowController
			accountsFeedbinWindowController.account = account
			accountsFeedbinWindowController.runSheetOnWindow(window)

		case .inoreader, .bazQux, .theOldReader, .freshRSS:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsWindowController = accountsReaderAPIWindowController
			accountsReaderAPIWindowController.accountType = account.type
			accountsReaderAPIWindowController.account = account
			accountsReaderAPIWindowController.runSheetOnWindow(window)

		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsWindowController = accountsNewsBlurWindowController
			accountsNewsBlurWindowController.account = account
			accountsNewsBlurWindowController.runSheetOnWindow(window)

		default:
			break
		}
	}

	@IBAction func changePath(_ sender: Any) {
		guard let window = view.window else {
			return
		}

		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.message = NSLocalizedString("Choose storage location for On My Mac account", comment: "Open panel message")
		panel.prompt = NSLocalizedString("Choose", comment: "Open panel button")

		panel.beginSheetModal(for: window) { [weak self] response in
			guard response == .OK, let url = panel.url else {
				return
			}
			self?.handlePathChange(to: url.path)
		}
	}

	private func handlePathChange(to newPath: String) {
		guard let account = account else {
			return
		}

		let oldPath = account.dataFolder

		// If the path hasn't changed, do nothing
		if oldPath == newPath {
			return
		}

		// Verify the new path is writable
		let fileManager = FileManager.default
		if !fileManager.isWritableFile(atPath: newPath) {
			showAlert(
				title: NSLocalizedString("Cannot Use This Location", comment: "Alert title"),
				message: NSLocalizedString("The selected location is not writable. Please choose a different location.", comment: "Alert message")
			)
			return
		}

		// Perform data migration
		do {
			try migrateData(from: oldPath, to: newPath)
		} catch {
			showAlert(
				title: NSLocalizedString("Migration Failed", comment: "Alert title"),
				message: String(format: NSLocalizedString("Could not copy data to the new location: %@", comment: "Alert message"), error.localizedDescription)
			)
			return
		}

		// Save the new path to UserDefaults
		AppDefaults.shared.onMyMacAccountPath = newPath

		// Update the UI
		storagePathTextField?.stringValue = newPath
		storagePathTextField?.toolTip = newPath

		// Show restart required alert
		showRestartRequiredAlert()
	}

	private func migrateData(from oldPath: String, to newPath: String) throws {
		let fileManager = FileManager.default

		// Files to migrate
		let filesToMigrate = ["DB.sqlite3", "DB.sqlite3-shm", "DB.sqlite3-wal", "Subscriptions.opml", "Settings.plist", "FeedMetadata.plist"]

		for filename in filesToMigrate {
			let sourcePath = (oldPath as NSString).appendingPathComponent(filename)
			let destPath = (newPath as NSString).appendingPathComponent(filename)

			if fileManager.fileExists(atPath: sourcePath) {
				// Remove existing file at destination if it exists
				if fileManager.fileExists(atPath: destPath) {
					try fileManager.removeItem(atPath: destPath)
				}
				try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
			}
		}
	}

	private func showRestartRequiredAlert() {
		guard let window = view.window else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Restart Required", comment: "Alert title")
		alert.informativeText = NSLocalizedString("The storage location has been changed. NetNewsWire needs to restart for the change to take effect. Your original data has been preserved as a backup.", comment: "Alert message")
		alert.addButton(withTitle: NSLocalizedString("Restart Now", comment: "Alert button"))
		alert.addButton(withTitle: NSLocalizedString("Later", comment: "Alert button"))
		alert.beginSheetModal(for: window) { response in
			if response == .alertFirstButtonReturn {
				self.restartApp()
			}
		}
	}

	private func restartApp() {
		let url = URL(fileURLWithPath: Bundle.main.bundlePath)
		let configuration = NSWorkspace.OpenConfiguration()
		configuration.createsNewApplicationInstance = true

		NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
			DispatchQueue.main.async {
				NSApplication.shared.terminate(nil)
			}
		}
	}

	private func showAlert(title: String, message: String) {
		guard let window = view.window else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = title
		alert.informativeText = message
		alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert button"))
		alert.beginSheetModal(for: window)
	}
}
