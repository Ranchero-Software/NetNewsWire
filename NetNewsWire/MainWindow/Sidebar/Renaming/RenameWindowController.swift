//
//  RenameWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

protocol RenameWindowControllerDelegate {

	func renameWindowController(_ windowController: RenameWindowController, didRenameObject: Any, withNewName: String)
}

final class RenameWindowController: NSWindowController {

	@IBOutlet var renamePrompt: NSTextField!
	@IBOutlet var newTitleTextField: NSTextField!
	@IBOutlet var renameButton: NSButton!
	
	private var originalTitle: String?
	private var representedObject: Any?
	private var delegate: RenameWindowControllerDelegate?

	convenience init(originalTitle: String, representedObject: Any, delegate: RenameWindowControllerDelegate) {

		self.init(windowNibName: NSNib.Name("RenameSheet"))
		self.originalTitle = originalTitle
		self.representedObject = representedObject
		self.delegate = delegate
	}

	override func windowDidLoad() {

		newTitleTextField.stringValue = originalTitle!

		let prompt = NSLocalizedString("Rename %@ to:", comment: "Rename sheet")
		let localizedPrompt = NSString.localizedStringWithFormat(prompt as NSString, originalTitle!)
		renamePrompt.stringValue = localizedPrompt as String

		updateUI()
	}

	// MARK: Actions

	@IBAction func cancel(_ sender: Any?) {

		window?.sheetParent?.endSheet(window!, returnCode: .cancel)
	}

	@IBAction func rename(_ sender: Any?) {

		guard let representedObject = representedObject else {
			return
		}
		delegate?.renameWindowController(self, didRenameObject: representedObject, withNewName: newTitleTextField.stringValue)
		window?.sheetParent?.endSheet(window!, returnCode: .OK)
	}

}

extension RenameWindowController: NSTextFieldDelegate {

	func controlTextDidChange(_ obj: Notification) {

		updateUI()
	}
}

private extension RenameWindowController {

	func updateUI() {

		let newTitle = newTitleTextField.stringValue
		renameButton.isEnabled = !newTitle.isEmpty && newTitle != originalTitle
	}
}
