//
//  AddFeedbinAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSWeb

class FeedbinAccountViewController: UIViewController {

	@IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var doneBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var emailTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var errorMessageLabel: UILabel!
	
	weak var account: Account?
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
        super.viewDidLoad()

		activityIndicator.isHidden = true
		
		if let account = account, let credentials = try? account.retrieveBasicCredentials() {
			if case .basic(let username, let password) = credentials {
				emailTextField.text = username
				passwordTextField.text = password
			}
		}
	}
	
	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	@IBAction func done(_ sender: Any) {

		self.errorMessageLabel.text = nil
		
		guard emailTextField.text != nil && passwordTextField.text != nil else {
			self.errorMessageLabel.text = NSLocalizedString("Username & password required.", comment: "Credentials Error")
			return
		}
		
		cancelBarButtonItem.isEnabled = false
		doneBarButtonItem.isEnabled = false
		activityIndicator.isHidden = false
		activityIndicator.startAnimating()
		
		let credentials = Credentials.basic(username: emailTextField.text ?? "", password: passwordTextField.text ?? "")
		Account.validateCredentials(type: .feedbin, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.cancelBarButtonItem.isEnabled = true
			self.doneBarButtonItem.isEnabled = true
			self.activityIndicator.isHidden = true
			self.activityIndicator.stopAnimating()
			
			switch result {
			case .success(let authenticated):
				
				if authenticated {
					
					var newAccount = false
					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					}
					
					do {
						try self.account?.removeBasicCredentials()
						try self.account?.storeCredentials(credentials)
						if newAccount {
							self.account?.refreshAll()
						}
						self.dismiss(animated: true)
						self.delegate?.dismiss()
					} catch {
						self.errorMessageLabel.text = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
					}
					
				} else {
					self.errorMessageLabel.text = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
				}
				
			case .failure:
				
				self.errorMessageLabel.text = NSLocalizedString("Network error.  Try again later.", comment: "Credentials Error")
				
			}
			
		}
		
	}

}
