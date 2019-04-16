//
//  AddAccountViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit

class AddAccountViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

		// I couldn't figure out the gap at the top of the UITableView, so I took a hammer to it.
		tableView.contentInset = UIEdgeInsets(top: -28, left: 0, bottom: 0, right: 0)

	}

}
