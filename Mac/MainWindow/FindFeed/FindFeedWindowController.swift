//
//  FindFeedWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSParser
import RSTree
import RSWeb
import Articles
import Account

protocol FindFeedWindowControllerDelegate: class {

	// userEnteredURL will have already been validated and normalized.
	func findFeedWindowController(_: FindFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)

	func findFeedWindowControllerUserDidCancel(_: FindFeedWindowController)
}

class FindFeedWindowController : NSWindowController {
    
    @IBOutlet var urlTextField: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!

	private weak var delegate: FindFeedWindowControllerDelegate?

	private var userEnteredTitle: String? {
		var s = nameTextField.stringValue
		s = s.rs_stringWithCollapsedWhitespace()
		if s.isEmpty {
			return nil
		}
		return s
	}
	
	convenience init(delegate: FindFeedWindowControllerDelegate?) {
		self.init(windowNibName: NSNib.Name("FindFeedSheet"))
		self.delegate = delegate
	}
	
    func runSheetOnWindow(_ hostWindow: NSWindow) {
		
		hostWindow.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
    }

	override func windowDidLoad() {

		updateUI()
	}

    // MARK: Actions
    
    @IBAction func cancel(_ sender: Any?) {
		cancelSheet()
    }
    
    @IBAction func addFeed(_ sender: Any?) {
		let urlString = urlTextField.stringValue
		let normalizedURLString = (urlString as NSString).rs_normalizedURL()

		if normalizedURLString.isEmpty {
			cancelSheet()
			return;
		}
		guard let url = URL(string: normalizedURLString) else {
			cancelSheet()
			return
		}
		
		let container = selectedContainer()!
		if let selectedAccount = container as? Account {
			AppDefaults.addFeedAccountID = selectedAccount.accountID
		} else if let selectedFolder = container as? Folder, let selectedAccount = selectedFolder.account {
			AppDefaults.addFeedAccountID = selectedAccount.accountID
		}

		delegate?.findFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container)
		
    }
	
	// MARK: NSTextFieldDelegate

	@objc func controlTextDidEndEditing(_ obj: Notification) {
		updateUI()
	}

	lazy var debouncedSearch = debounce(interval: .milliseconds(300), queue: .main) {
		FeedFinder.find(query: self.urlTextField.stringValue) { [weak self] result in
			self?.nameTextField.stringValue = (try? result.get())?.joined(separator: "\n") ?? ""
		}
	}

	@objc func controlTextDidChange(_ obj: Notification) {
		debouncedSearch()
	}
}

private func debounce(interval dispatchDelay: DispatchTimeInterval, queue: DispatchQueue, action: @escaping (() -> Void)) -> () -> Void {
    var lastFireTime = DispatchTime.now()

    return {
        lastFireTime = DispatchTime.now()
        let dispatchTime: DispatchTime = DispatchTime.now() + dispatchDelay

        queue.asyncAfter(deadline: dispatchTime) {
            let when: DispatchTime = lastFireTime + dispatchDelay
            let now = DispatchTime.now()
            if now.rawValue >= when.rawValue {
                action()
            }
        }
    }
}

private extension FindFeedWindowController {
	
	private func updateUI() {
		addButton.isEnabled = urlTextField.stringValue.rs_stringMayBeURL()
	}

	func cancelSheet() {
		delegate?.findFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return nil
	}
}
