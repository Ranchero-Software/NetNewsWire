//
//  SafariExtensionViewController.swift
//  Subscribe to Feed
//
//  Created by Daniel Jalkut on 6/11/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {

	// This would be the place to handle a popover that could, for example, list the possibly multiple feeds offered by a site.
    static let shared: SafariExtensionViewController = {
        let shared = SafariExtensionViewController()
        shared.preferredContentSize = NSSize(width:320, height:240)
        return shared
    }()

}
