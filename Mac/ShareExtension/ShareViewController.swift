//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Maurice Parker on 8/13/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers
import Synchronization

final class ShareViewController: NSViewController {
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var folderPopUpButton: NSPopUpButton!

	private struct State: Sendable {
		var url: URL?
	}
	private let state = Mutex(State())

	nonisolated private var url: URL? {
		get {
			state.withLock { $0.url }
		}
		set {
			state.withLock { $0.url = newValue }
		}
	}
	private var extensionContainers: ExtensionContainers?

	override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    override func loadView() {
        super.loadView()

		extensionContainers = ExtensionContainersFile.read()
		buildFolderPopupMenu()

		var provider: NSItemProvider?

		// Try to get any HTML that is maybe passed in
		for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
			for itemProvider in item.attachments! {
				if itemProvider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
					provider = itemProvider
				}
			}
		}

		if provider != nil {
			provider!.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil, completionHandler: { [weak self] (pList, error) in
				if error != nil {
					return
				}
				guard let dataGraph = pList as? NSDictionary else {
					return
				}
				guard let results = dataGraph["NSExtensionJavaScriptPreprocessingResultsKey"] as? NSDictionary else {
					return
				}
				if let url = URL(string: results["url"] as! String) {
					self?.url = url
				}
			})
			return
		}

		// Try to get the URL if it is passed in as a URL
		for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
			for itemProvider in item.attachments! {
				if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
					provider = itemProvider
				}
			}
		}

		if provider != nil {
			provider!.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil, completionHandler: { [weak self] (urlCoded, error) in
				if error != nil {
					return
				}
				if let url = urlCoded as? URL {
					self?.url = url
					return
				}
				if let urlData = urlCoded as? Data {
					self?.url = URL(dataRepresentation: urlData, relativeTo: nil)
				}
			})
		}
	}

    @IBAction func send(_ sender: AnyObject?) {
		guard let url, let selectedContainer = selectedContainer(), let containerID = selectedContainer.containerID else {
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			return
		}

		let name = nameTextField.stringValue.isEmpty ? nil : nameTextField.stringValue
		let request = ExtensionFeedAddRequest(name: name, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)

		self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
	}

    @IBAction func cancel(_ sender: AnyObject?) {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: cancelError)
    }

}

private extension ShareViewController {

	func buildFolderPopupMenu() {

		let menu = NSMenu(title: "Folders")
		menu.autoenablesItems = false

		guard let extensionContainers = extensionContainers else {
			folderPopUpButton.menu = nil
			return
		}

		let defaultContainer = ShareDefaultContainer.defaultContainer(containers: extensionContainers)
		var defaultMenuItem: NSMenuItem?

		for account in extensionContainers.accounts {

			let menuItem = NSMenuItem(title: account.name, action: nil, keyEquivalent: "")
			menuItem.representedObject = account

			if account.disallowFeedInRootFolder {
				menuItem.isEnabled = false
			}

			menu.addItem(menuItem)

			if defaultContainer?.containerID == account.containerID {
				defaultMenuItem = menuItem
			}

			for folder in account.folders {
				let menuItem = NSMenuItem(title: folder.name, action: nil, keyEquivalent: "")
				menuItem.indentationLevel = 1
				menuItem.representedObject = folder
				menu.addItem(menuItem)
				if defaultContainer?.containerID == folder.containerID {
					defaultMenuItem = menuItem
				}
			}

		}

		folderPopUpButton.menu = menu
		folderPopUpButton.select(defaultMenuItem)
	}

	func selectedContainer() -> ExtensionContainer? {
		return folderPopUpButton.selectedItem?.representedObject as? ExtensionContainer
	}

}
