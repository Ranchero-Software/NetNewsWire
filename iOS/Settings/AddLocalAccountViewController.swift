//
//  AddLocalAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class AddLocalAccountViewController: UIViewController {

	@IBOutlet private weak var localAccountNameLabel: UILabel!
	@IBOutlet weak var nameTextField: UITextField!
	
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		
		localAccountNameLabel.text = Account.defaultLocalAccountName
		nameTextField.delegate = self
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	@IBAction func done(_ sender: Any) {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = nameTextField.text
		dismiss(animated: true)
		delegate?.dismiss()
	}
	
}

extension AddLocalAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
