//
//  LocalAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class LocalAccountViewController: UITableViewController {

	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var footerLabel: UILabel!
	
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		setupFooter()
		navigationItem.title = Account.defaultLocalAccountName
		nameTextField.delegate = self
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}
	
	private func setupFooter() {
		footerLabel.text = NSLocalizedString("Local accounts do not sync your subscriptions across devices.", comment: "Local")
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
	}
	
	@IBAction func add(_ sender: Any) {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = nameTextField.text
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = AppAssets.image(for: .onMyMac)
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}
	
}

extension LocalAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
