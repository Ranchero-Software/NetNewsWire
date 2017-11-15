//
//  LogWindowController.swift
//  RSCore
//
//  Created by Brent Simmons on 11/13/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class LogWindowController: NSWindowController {

	@IBOutlet private var textView: NSTextView!
	private var title: String!
//	private let attributes = [NSFont.Att
	public convenience init(title: String) {

		self.init(windowNibName: NSNib.Name(rawValue: "LogWindow"))
		self.title = title
	}

    override func windowDidLoad() {

        window!.title = title
    }

	public func appendLine(_ s: String) {

		// Adds two line feeds before the text.


	}

	public func setTextViewText(_ s: String) {

		let attributedString = NSAttributedString(string: s)
		textView.textStorage?.setAttributedString(attributedString)

		validateButtons()
	}

	// MARK: - Actions

	@IBAction func clearContents(_ sender: Any?) {

		setTextViewText("")
	}

	@IBAction func saveToFile(_ sender: Any?) {

	}

}

private extension LogWindowController {

	func validateButtons() {

	}


}
