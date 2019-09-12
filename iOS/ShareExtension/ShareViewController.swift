//
//  ShareViewController.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import MobileCoreServices
import Social
import Account
import Articles
import RSCore
import RSTree

class ShareViewController: SLComposeServiceViewController, ShareFolderPickerControllerDelegate {
	
	private var pickerData: FlattenedAccountFolderPickerData?

	private var url: URL?
	private var container: Container?
	
	override func viewDidLoad() {
		
		AccountManager.shared = AccountManager(accountsFolder: RSDataSubfolder(nil, "Accounts")!)
		pickerData = FlattenedAccountFolderPickerData()
		
		if pickerData?.containers.count ?? 0 > 0 {
			container = pickerData?.containers[0]
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
			})
		}
		
	}
	
	override func isContentValid() -> Bool {
		return url != nil && container != nil
	}
	
	override func didSelectPost() {

		var account: Account?
		if let containerAccount = container as? Account {
			account = containerAccount
		} else if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
		}
		
		if let urlString = url?.absoluteString, account!.hasFeed(withURL: urlString) {
			presentError(AccountError.createErrorAlreadySubscribed)
 			return
		}
		
		let feedName = contentText.isEmpty ? nil : contentText
		
		account!.createFeed(url: url!.absoluteString, name: feedName, container: container!) { result in

			switch result {
			case .success:
				self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			case .failure(let error):
				self.presentError(error) {
					self.extensionContext!.cancelRequest(withError: error)
				}
			}

		}

		
		
		// This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
		
		// Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
	}
	
	func shareFolderPickerDidSelect(_ container: Container) {
		self.container = container
	}

	override func configurationItems() -> [Any]! {
		
		// To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
		guard let urlItem = SLComposeSheetConfigurationItem() else { return nil }
		urlItem.title = "URL"
		urlItem.value = url?.absoluteString ?? ""
		
		guard let folderItem = SLComposeSheetConfigurationItem() else { return nil }
		folderItem.title = "Folder"
		
		if let nameProvider = container as? DisplayNameProvider {
			folderItem.value = nameProvider.nameForDisplay
		}
		
		folderItem.tapHandler = {
			
			let folderPickerController = ShareFolderPickerController()
			
			folderPickerController.navigationController?.title = NSLocalizedString("Folder", comment: "Folder")
			folderPickerController.delegate = self
			folderPickerController.pickerData = self.pickerData
			folderPickerController.selectedContainer = self.container
			
			self.pushConfigurationViewController(folderPickerController)
			
		}
		
		return [folderItem, urlItem]
		
	}
	
}
