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

	@IBOutlet weak var nameTextField: UITextField!
	weak var delegate: AddAccountDismissDelegate?
	
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
