//
//  AddFeedWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account

protocol AddFeedWindowControllerDelegate: class {

	// userEnteredURL will have already been validated and normalized.
	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)

	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController)
}

class AddFeedWindowController : NSWindowController {
    
    @IBOutlet var urlTextField: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var folderPopupButton: NSPopUpButton!

	private var urlString: String?
	private var initialName: String?
	fileprivate weak var delegate: AddFeedWindowControllerDelegate?
	fileprivate var folderTreeController: TreeController!

	private var userEnteredTitle: String? {
		var s = nameTextField.stringValue
		s = s.rs_stringWithCollapsedWhitespace()
		if s.isEmpty {
			return nil
		}
		return s
	}
	
    var hostWindow: NSWindow!

	convenience init(urlString: String?, name: String?, folderTreeController: TreeController, delegate: AddFeedWindowControllerDelegate?) {
		
		self.init(windowNibName: NSNib.Name(rawValue: "AddFeedSheet"))
		self.urlString = urlString
		self.initialName = name
		self.delegate = delegate
		self.folderTreeController = folderTreeController
	}
	
    func runSheetOnWindow(_ w: NSWindow) {
        
        hostWindow = w
        hostWindow.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
    }

	override func windowDidLoad() {

		if let urlString = urlString {
			urlTextField.stringValue = urlString
		}
		if let initialName = initialName, !initialName.isEmpty {
			nameTextField.stringValue = initialName
		}

		folderPopupButton.menu = createFolderPopupMenu()
		updateUI()
	}

	private func updateUI() {

		var addButtonEnabled = false
		let urlString = urlTextField.stringValue
		if urlString.rs_stringMayBeURL() {
			addButtonEnabled = true
		}

		addButton.isEnabled = addButtonEnabled
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

		delegate?.addFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: selectedContainer()!)
    }

	@IBAction func localShowFeedList(_ sender: Any?) {
		
		NSApplication.shared.sendAction(NSSelectorFromString("showFeedList:"), to: nil, from: sender)
		hostWindow.endSheet(window!, returnCode: NSApplication.ModalResponse.continue)
	}
	
	// MARK: NSTextFieldDelegate

	override func controlTextDidEndEditing(_ obj: Notification) {

		updateUI()
	}

	override func controlTextDidChange(_ obj: Notification) {

		updateUI()
	}
}

private extension AddFeedWindowController {
	
	func cancelSheet() {

		delegate?.addFeedWindowControllerUserDidCancel(self)
	}


	func selectedContainer() -> Container? {

		return folderPopupButton.selectedItem?.representedObject as? Container
	}

	func createFolderPopupMenu() -> NSMenu {

		let menu = NSMenu(title: "Folders")

		let menuItem = NSMenuItem(title: NSLocalizedString("Top Level", comment: "Add Feed Sheet"), action: nil, keyEquivalent: "")
		menuItem.representedObject = folderTreeController.rootNode.representedObject
		menu.addItem(menuItem)

		let childNodes = folderTreeController.rootNode.childNodes
		addFolderItemsToMenuWithNodes(menu: menu, nodes: childNodes, indentationLevel: 1)

		return menu
	}

	func addFolderItemsToMenuWithNodes(menu: NSMenu, nodes: [Node], indentationLevel: Int) {

		nodes.forEach { (oneNode) in

			if let nameProvider = oneNode.representedObject as? DisplayNameProvider {

				let menuItem = NSMenuItem(title: nameProvider.nameForDisplay, action: nil, keyEquivalent: "")
				menuItem.indentationLevel = indentationLevel
				menuItem.representedObject = oneNode.representedObject
				menu.addItem(menuItem)

				if oneNode.numberOfChildNodes > 0 {
					addFolderItemsToMenuWithNodes(menu: menu, nodes: oneNode.childNodes, indentationLevel: indentationLevel + 1)
				}
			}
		}
	}
}
