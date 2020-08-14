//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Maurice Parker on 8/13/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa

class ShareViewController: NSViewController {

	private var url: URL?
	private var extensionContainers: ExtensionContainers?
	private var flattenedContainers: [ExtensionContainer]!
	private var selectedContainer: ExtensionContainer?
	
	override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    override func loadView() {
        super.loadView()
		
		extensionContainers = ExtensionContainersFile.read()
		flattenedContainers = extensionContainers?.flattened ?? [ExtensionContainer]()
		if let extensionContainers = extensionContainers {
			selectedContainer = ShareDefaultContainer.defaultContainer(containers: extensionContainers)
		}

		var provider: NSItemProvider? = nil

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

    @IBAction func send(_ sender: AnyObject?) {
		guard let url = url, let selectedContainer = selectedContainer, let containerID = selectedContainer.containerID else {
			self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
			return
		}

//		let name = contentText.isEmpty ? nil : contentText
//		let request = ExtensionFeedAddRequest(name: name, feedURL: url, destinationContainerID: containerID)
//		ExtensionFeedAddRequestFile.save(request)
		
		self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
	}

    @IBAction func cancel(_ sender: AnyObject?) {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        self.extensionContext!.cancelRequest(withError: cancelError)
    }

}
