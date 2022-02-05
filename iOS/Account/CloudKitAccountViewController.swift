//
//  CloudKitAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 3/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

enum CloudKitAccountViewControllerError: LocalizedError {
	case iCloudDriveMissing
	
	var errorDescription: String? {
		return NSLocalizedString("UNABLE_TO_ADD_ICLOUD_ACCOUNT", comment: "Unable to add iCloud Account.")
	}
}

class CloudKitAccountViewController: UITableViewController {

	weak var delegate: AddAccountDismissDelegate?
	@IBOutlet weak var footerLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFooter()
		
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}
	
	private func setupFooter() {
		footerLabel.text = NSLocalizedString("ICLOUD_EXPLAINER_LONG", comment: "iCloud")
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func add(_ sender: Any) {
		guard FileManager.default.ubiquityIdentityToken != nil else {
			presentError(CloudKitAccountViewControllerError.iCloudDriveMissing)
			return
		}
		
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
