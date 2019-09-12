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

class ShareViewController: SLComposeServiceViewController {
	
	private var url: URL?
	
	override func viewDidLoad() {
		
		AccountManager.shared = AccountManager(accountsFolder: RSDataSubfolder(nil, "Accounts")!)

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
		return url != nil
	}
	
	override func didSelectPost() {

		// Temporarily hardcoded
		let account = AccountManager.shared.activeAccounts.first
		let container = account!
		
		let feedName = contentText.isEmpty ? nil : contentText
		
		account!.createFeed(url: url!.absoluteString, name: feedName, container: container) { result in

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
	
	override func configurationItems() -> [Any]! {
		
		// To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
		guard let urlItem = SLComposeSheetConfigurationItem() else { return nil }
		urlItem.title = "URL"
		urlItem.value = url?.absoluteString ?? ""
		
		guard let folderItem = SLComposeSheetConfigurationItem() else { return nil }
		folderItem.title = "Folder"
		folderItem.value = "On My iPhone"
		folderItem.tapHandler = {
			print("Tapped that!")
		}
		
		// Example how you might navigate to a UIViewController with an edit field...
		//        aliasConfigItem.tapHandler = {
		//
		//            let aliasEditViewController = UIViewController()
		//            aliasEditViewController.navigationController?.title = "Alias"
		//
		//            let textField = UITextField(frame: CGRectMake(10,10,self.view.frame.width - 50,50))
		//            textField.borderStyle = UITextBorderStyle.RoundedRect;
		//            textField.placeholder = "enter your alias";
		//            textField.keyboardType = UIKeyboardType.Default;
		//            textField.returnKeyType = UIReturnKeyType.Done;
		//            aliasEditViewController.view.addSubview(textField)
		//
		//            self.pushConfigurationViewController(aliasEditViewController)
		//        }
		
		return [folderItem, urlItem]
	}
	
}
