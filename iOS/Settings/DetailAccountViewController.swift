//
//  DetailAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class DetailAccountViewController: UITableViewController {

	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var activeSwitch: UISwitch!
	
	weak var account: Account?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		guard let account = account else { return }
		nameTextField.text = account.name
		nameTextField.delegate = self
		activeSwitch.isOn = account.isActive
    }

	override func viewWillDisappear(_ animated: Bool) {
		account?.name = nameTextField.text
		account?.isActive = activeSwitch.isOn
	}
	
}

extension DetailAccountViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		if account == AccountManager.shared.defaultAccount {
			return 1
		} else {
			return super.numberOfSections(in: tableView)
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		
		let bgView = UIView()
		bgView.backgroundColor = AppAssets.selectionBackgroundColor
		cell.selectedBackgroundView = bgView
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.section == 1 {
			deleteAccount()
		}
		
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}
	
}

private extension DetailAccountViewController {
	
	func deleteAccount() {
		let title = NSLocalizedString("Delete Account", comment: "Delete Account")
		let message = NSLocalizedString("Are you sure you want to delete this account?  This can not be undone.", comment: "Delete Account")
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Delete", comment: "Delete")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in
			guard let account = self?.account else { return }
			AccountManager.shared.deleteAccount(account)
			self?.navigationController?.popViewController(animated: true)
		}
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
	}
	
}

extension DetailAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
