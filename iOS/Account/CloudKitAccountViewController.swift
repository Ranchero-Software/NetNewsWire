//
//  CloudKitAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 3/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class CloudKitAccountViewController: UITableViewController {

	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func add(_ sender: Any) {
		let _ = AccountManager.shared.createAccount(type: .cloudKit)
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = AppAssets.image(for: .cloudKit)
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}
	
}
