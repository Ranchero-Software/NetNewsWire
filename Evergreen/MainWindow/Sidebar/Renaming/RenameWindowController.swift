//
//  RenameWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

final class RenameWindowController: NSWindowController {

	@IBOutlet var renamePrompt: NSTextField!
	@IBOutlet var newTitleTextField: NSTextField!
	@IBOutlet var renameButton: NSButton!
	
	private var originalTitle: String!
	private var hostWindow: NSWindow!
	private var callback: ((String?) -> Void)?

	convenience init(originalTitle: String, callback: @escaping ((String?) -> Void)) {

		self.init(windowNibName: NSNib.Name(rawValue: "RenameSheet"))
		self.originalTitle = originalTitle
		self.callback = callback
	}

	override func windowDidLoad() {

		newTitleTextField.stringValue = originalTitle

		let prompt = NSLocalizedString("Rename %@ to:", comment: "Rename sheet")
		let localizedPrompt = NSString.localizedStringWithFormat(prompt as NSString, originalTitle)
		renamePrompt.stringValue = localizedPrompt as String

		updateUI()
	}

	func runSheetOnWindow(_ w: NSWindow) {

		guard let window = window else {
			return
		}

		hostWindow = w
		hostWindow.beginSheet(window) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
	}

	// MARK: Actions

	@IBAction func cancel(_ sender: AnyObject) {

		callback?(nil)
		hostWindow!.endSheet(window!, returnCode: .cancel)
	}

	@IBAction func rename(_ sender: AnyObject) {

		callback?(newTitleTextField.stringValue)
		hostWindow!.endSheet(window!, returnCode: .OK)
	}

}

extension RenameWindowController: NSTextFieldDelegate {

	override func controlTextDidChange(_ obj: Notification) {

		updateUI()
	}
}

private extension RenameWindowController {

	func updateUI() {

		let newTitle = newTitleTextField.stringValue
		renameButton.isEnabled = !newTitle.isEmpty && newTitle != originalTitle
	}
}
