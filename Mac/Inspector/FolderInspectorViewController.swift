//
//  FolderInspectorViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

final class FolderInspectorViewController: NSViewController, Inspector {

	@IBOutlet var nameTextField: NSTextField?
	@IBOutlet var folderImageView: NSImageView!

	private var folder: Folder? {
		didSet {
			if folder != oldValue {
				updateUI()
			}
		}
	}

	// MARK: Inspector

	let isFallbackInspector = false
	var objects: [Any]? {
		didSet {
			renameFolderIfNecessary()
			updateFolder()
		}
	}
	var windowTitle: String = NSLocalizedString("Folder Inspector", comment: "Folder Inspector window title")

	func canInspect(_ objects: [Any]) -> Bool {
		guard singleFolder(from: objects) != nil else {
			return false
		}
		return true
	}

	// MARK: NSViewController

	override func viewDidLoad() {
		updateUI()

		let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
		folderImageView.image = image
		folderImageView.contentTintColor = NSColor.controlAccentColor

		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
	}

	override func viewDidDisappear() {
		renameFolderIfNecessary()
	}

	// MARK: Notifications

	@objc func displayNameDidChange(_ note: Notification) {
		guard let updatedFolder = note.object as? Folder, updatedFolder == folder else {
			return
		}
		updateUI()
	}
}

extension FolderInspectorViewController: NSTextFieldDelegate {

	func controlTextDidEndEditing(_ obj: Notification) {
		renameFolderIfNecessary()
	}

}

private extension FolderInspectorViewController {

	func singleFolder(from objects: [Any]?) -> Folder? {

		guard let objects = objects, objects.count == 1, let singleFolder = objects.first as? Folder else {
			return nil
		}

		return singleFolder
	}

	func updateFolder() {

		folder = singleFolder(from: objects)
	}

	func updateUI() {

		guard let nameTextField = nameTextField else {
			return
		}

		let name = folder?.nameForDisplay ?? ""
		if nameTextField.stringValue != name {
			nameTextField.stringValue = name
		}
		windowTitle = folder?.nameForDisplay ?? NSLocalizedString("Folder Inspector", comment: "Folder Inspector window title")
	}

	func renameFolderIfNecessary() {
		guard let folder, let account = folder.account, let nameTextField else {
			return
		}

		let newFolderName = nameTextField.stringValue
		guard !newFolderName.isEmpty, folder.nameForDisplay != newFolderName else {
			return
		}

		Task { @MainActor in
			do {
				try await account.renameFolder(folder, to: newFolderName)
				windowTitle = folder.nameForDisplay
			} catch {
				presentError(error)
			}
		}
	}
}
