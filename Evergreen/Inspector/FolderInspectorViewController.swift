//
//  FolderInspectorViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/20/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class FolderInspectorViewController: NSViewController, Inspector {

	@IBOutlet var nameTextField: NSTextField?

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
			updateFolder()
		}
	}

	func canInspect(_ objects: [Any]) -> Bool {

		guard let _ = singleFolder(from: objects) else {
			return false
		}
		return true
	}

	// MARK: NSViewController

	override func viewDidLoad() {

		updateUI()
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

		nameTextField?.stringValue = folder?.nameForDisplay ?? ""
	}

}
