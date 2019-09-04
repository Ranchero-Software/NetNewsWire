//
//  RootSplitViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class RootSplitViewController: UISplitViewController {
	
	var coordinator: SceneCoordinator!
	
	// MARK: Keyboard Shortcuts
	
	@objc func openInBrowser(_ sender: Any?) {
		coordinator.showBrowserForCurrentArticle()
	}
	
}
