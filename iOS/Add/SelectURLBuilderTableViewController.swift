//
//  SelectURLBuilderTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

class SelectURLBuilderTableViewController: UITableViewController, SelectURLBuilder {

	weak var delegate: SelectURLBuilderDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "URLBuilderCell", for: indexPath) as! SelectComboTableViewCell
		cell.icon?.image = AppAssets.extensionPointTwitter
		cell.label?.text = NSLocalizedString("Twitter", comment: "Twitter")
        return cell
    }

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let twitterURLBuilder = UIStoryboard.twitterAdd.instantiateInitialViewController() as! TwitterSelectTypeTableViewController
		twitterURLBuilder.delegate = delegate
		navigationController?.pushViewController(twitterURLBuilder, animated: true)
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
}
