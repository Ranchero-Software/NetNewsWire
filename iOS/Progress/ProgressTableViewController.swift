//
//  ProgressTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ProgressTableViewController: UITableViewController {
	
	override func viewDidLoad() {
		super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		navigationController?.updateAccountRefreshProgressIndicator()
	}
	
	@objc func progressDidChange(_ note: Notification) {
		navigationController?.updateAccountRefreshProgressIndicator()
	}
	
}
