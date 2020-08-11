//
//  AddFolderViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import Account
import RSCore

class AddFolderViewController: UITableViewController {

	@IBOutlet private weak var addButton: UIBarButtonItem!
	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var accountLabel: UILabel!
	@IBOutlet private weak var accountPickerView: UIPickerView!
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)
	
	private var shouldDisplayPicker: Bool {
		return accounts.count > 1
	}
	
	private var accounts: [Account]! {
		didSet {
			if let predefinedAccount = accounts.first(where: { $0.accountID == AppDefaults.shared.addFolderAccountID }) {
				selectedAccount = predefinedAccount
			} else {
				selectedAccount = accounts[0]
			}
		}
	}

	private var selectedAccount: Account! {
		didSet {
			guard selectedAccount != oldValue else { return }
			accountLabel.text = selectedAccount.flatMap { ($0 as DisplayNameProvider).nameForDisplay }
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		accounts = AccountManager.shared
			.sortedActiveAccounts
			.filter { !$0.behaviors.contains(.disallowFolderManagement) }
		
		nameTextField.delegate = self
		
		if shouldDisplayPicker {
			accountPickerView.dataSource = self
			accountPickerView.delegate = self
			
			if let index = accounts.firstIndex(of: selectedAccount) {
				accountPickerView.selectRow(index, inComponent: 0, animated: false)
			}
			
		} else {
			accountPickerView.isHidden = true
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nameTextField)
		
		nameTextField.becomeFirstResponder()
    }
	
	private func didSelect(_ account: Account) {
		AppDefaults.shared.addFolderAccountID = account.accountID
		selectedAccount = account
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {
		guard let folderName = nameTextField.text else {
			return
		}
		selectedAccount.addFolder(folderName) { result in
			switch result {
			case .success:
				self.dismiss(animated: true)
			case .failure(let error):
				self.presentError(error)
				self.dismiss(animated: true)
			}
		}
	}

	@objc func textDidChange(_ note: Notification) {
		addButton.isEnabled = !(nameTextField.text?.isEmpty ?? false)
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
		if section == 1 && !shouldDisplayPicker {
			return defaultNumberOfRows - 1
		}
		
		return defaultNumberOfRows	
	}
}

extension AddFolderViewController: UIPickerViewDataSource, UIPickerViewDelegate {
	
	func numberOfComponents(in pickerView: UIPickerView) ->Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return accounts.count
	}
	
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return (accounts[row] as DisplayNameProvider).nameForDisplay
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		didSelect(accounts[row])
	}
	
}

extension AddFolderViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
