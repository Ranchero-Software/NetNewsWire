//
//  CloudKitAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 3/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import Account

final class CloudKitAccountViewController: UITableViewController {

	weak var delegate: AddAccountDismissDelegate?
	@IBOutlet weak var footerLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFooter()
		
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}
	
	private func setupFooter() {
		footerLabel.text = NSLocalizedString("NetNewsWire will use your iCloud account to sync your subscriptions across your Mac and iOS devices.", comment: "iCloud")
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func add(_ sender: Any) {
		if FileManager.default.ubiquityIdentityToken == nil { // iCloud Drive not available?
			let errorTitle = NSLocalizedString("Can’t add iCloud account because iCloud Drive is not enabled", comment:"iCloud not set up error title")
			let errorMessage = NSLocalizedString("Make sure you have iCloud and iCloud Drive enabled in System Settings.", comment: "iCloud not set up error message.")
			presentError(title: errorTitle, message: errorMessage)
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

	@IBAction func openLimitationsAndSolutions(_ sender: Any) {
		let vc = SFSafariViewController(url: CloudKitWebDocumentation.limitationsAndSolutionsURL)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}
