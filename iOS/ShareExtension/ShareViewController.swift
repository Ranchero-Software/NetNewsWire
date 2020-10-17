//
//  ShareViewController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import MobileCoreServices
import Account
import Social
import RSCore
import RSTree

class ShareViewController: SLComposeServiceViewController, ShareFolderPickerControllerDelegate {
	
	private var url: URL?
	private var extensionContainers: ExtensionContainers?
	private var flattenedContainers: [ExtensionContainer]!
	private var selectedContainer: ExtensionContainer?
	private var folderItem: SLComposeSheetConfigurationItem!
	
	override func viewDidLoad() {
		
		extensionContainers = ExtensionContainersFile.read()
		flattenedContainers = extensionContainers?.flattened ?? [ExtensionContainer]()
		if let extensionContainers = extensionContainers {
			selectedContainer = ShareDefaultContainer.defaultContainer(containers: extensionContainers)
		}

		title = "NetNewsWire"
		placeholder = "Feed Name (Optional)"
		if let button = navigationController?.navigationBar.topItem?.rightBarButtonItem {
			button.title = "Add Feed"
			button.isEnabled = true
		}

		// Hack the bottom table rows to be smaller since the controller itself doesn't have enough sense to size itself correctly
		if let nav = self.children.first as? UINavigationController, let tableView = nav.children.first?.view.subviews.first as? UITableView {
			tableView.rowHeight = 38
		}

		var provider: NSItemProvider? = nil

		// Try to get any HTML that is maybe passed in
		for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
			for itemProvider in item.attachments! {
				if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
					provider = itemProvider
				}
			}
		}

		if provider != nil  {
			provider!.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { [weak self] (pList, error) in
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

		// Try to get the URL if it is passed in
		for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
			for itemProvider in item.attachments! {
				if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
					provider = itemProvider
				}
			}
		}

		if provider != nil  {
			provider!.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { [weak self] (urlCoded, error) in
				if error != nil {
					return
				}
				guard let url = urlCoded as? URL else {
					return
				}
				self?.url = url
				return
			})
		}
		
		// Reddit in particular doesn't pass the URL correctly and instead puts it in the contentText
		url = URL(string: contentText)
	}
	
	override func isContentValid() -> Bool {
		return url != nil && selectedContainer != nil
	}
	
	override func didSelectPost() {
		guard let url = url, let selectedContainer = selectedContainer, let containerID = selectedContainer.containerID else {
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			return
		}

		var name: String? = nil
		if !contentText.mayBeURL {
			name = contentText.isEmpty ? nil : contentText
		}
		
		let request = ExtensionFeedAddRequest(name: name, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)
		
		self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
	}
	
	func shareFolderPickerDidSelect(_ container: ExtensionContainer) {
		ShareDefaultContainer.saveDefaultContainer(container)
		self.selectedContainer = container
		updateFolderItemValue()
		self.popConfigurationViewController()
	}

	override func configurationItems() -> [Any]! {
		
		// To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
		guard let urlItem = SLComposeSheetConfigurationItem() else { return nil }
		urlItem.title = "URL"
		urlItem.value = url?.absoluteString ?? ""
		
		folderItem = SLComposeSheetConfigurationItem()
		folderItem.title = "Folder"
		updateFolderItemValue()
		
		folderItem.tapHandler = {
			
			let folderPickerController = ShareFolderPickerController()
			
			folderPickerController.navigationController?.title = NSLocalizedString("Folder", comment: "Folder")
			folderPickerController.delegate = self
			folderPickerController.containers = self.flattenedContainers
			folderPickerController.selectedContainerID = self.selectedContainer?.containerID
			
			self.pushConfigurationViewController(folderPickerController)
			
		}
		
		return [folderItem!, urlItem]
		
	}
	
}

private extension ShareViewController {
	
	func updateFolderItemValue() {
		if let account = selectedContainer as? ExtensionAccount {
			self.folderItem.value = account.name
		} else if let folder = selectedContainer as? ExtensionFolder {
			self.folderItem.value = "\(folder.accountName) / \(folder.name)"
		}
	}
	
}
