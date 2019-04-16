//Copyright © 2019 Vincode, Inc. All rights reserved.

import UIKit
import Account
import RSCore

class AddFolderViewController: UITableViewController {

	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var accountLabel: UILabel!
	@IBOutlet weak var accountPickerView: UIPickerView!
	
	private var accounts: [Account]!
	
	override func viewDidLoad() {

		super.viewDidLoad()
		
		accounts = AccountManager.shared.sortedAccounts
		accountLabel.text = (accounts[0] as DisplayNameProvider).nameForDisplay
		
		accountPickerView.dataSource = self
		accountPickerView.delegate = self
		
    }

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {
		
		let account = accounts[accountPickerView.selectedRow(inComponent: 0)]
		if let folderName = nameTextField.text {
			account.ensureFolder(with: folderName)
		}
		
		dismiss(animated: true)
		
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
		accountLabel.text = (accounts[row] as DisplayNameProvider).nameForDisplay
	}
	
}

extension AddFolderViewController: UITextFieldDelegate {
	
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		updateUI()
		return true
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		updateUI()
	}
	
}

private extension AddFolderViewController {
	
	private func updateUI() {
		addButton.isEnabled = !(nameTextField.text?.isEmpty ?? false)
	}

}
