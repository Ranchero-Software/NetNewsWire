//
//  LogWindowController.swift
//  RSCore
//
//  Created by Brent Simmons on 11/13/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public class LogWindowController: NSWindowController {

	@IBOutlet private var textView: NSTextView!
	private var title: String!
	private weak var log: Log?
//	private let attributes = [NSFont.Att

	public convenience init(title: String, log: Log) {

		self.init(windowNibName: NSNib.Name(rawValue: "LogWindow"))
		self.log = log
		self.title = title

		NotificationCenter.default.addObserver(self, selector: #selector(logDidAddItem(_:)), name: .LogDidAddItem, object: log)
	}

    public override func windowDidLoad() {

        window!.title = title
		addExistingLogItems()
    }

	// MARK: - Notifications

	@objc func logDidAddItem(_ note: Notification) {

		guard let logItem = note.userInfo?[Log.logItemKey] as? LogItem else {
			return
		}

		appendLogItem(logItem)
	}

	// MARK: - Actions

	@IBAction func clearContents(_ sender: Any?) {

		setTextViewAttributedString(NSAttributedString(string: ""))
	}

	@IBAction func saveToFile(_ sender: Any?) {

	}
}

private extension LogWindowController {

	func addExistingLogItems() {

		guard let logItems = log?.logItems else {
			return
		}

		let attString = NSMutableAttributedString()
		for logItem in logItems {
			let oneAttString = attributedString(for: logItem)
			attString.append(oneAttString)
		}

		textView.textStorage?.setAttributedString(attString)

		validateButtons()
	}

	func setTextViewAttributedString(_ attString: NSAttributedString) {

		textView.textStorage?.setAttributedString(attString)
		validateButtons()
	}

	func appendAttributedString(_ attString: NSAttributedString) {

		if !Thread.isMainThread {
			DispatchQueue.main.async {
				self.appendAttributedString(attString)
			}
			return
		}

		validateButtons()
	}

	func appendLogItem(_ logItem: LogItem) {

	}

	func attributedString(for logItem: LogItem) -> NSAttributedString {

		return NSAttributedString() //TODO

	}

	func validateButtons() {

	}


}
