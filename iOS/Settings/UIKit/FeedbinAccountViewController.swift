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

	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var emailTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var actionButton: UIButton!
	
	@IBOutlet weak var errorMessageLabel: UILabel!
	
	weak var account: Account?
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
        super.viewDidLoad()

		activityIndicator.isHidden = true
		emailTextField.delegate = self
		passwordTextField.delegate = self
		
		if let account = account, let credentials = try? account.retrieveCredentials() {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			if case .basic(let username, let password) = credentials {
				emailTextField.text = username
				passwordTextField.text = password
			}
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Update Credentials"), for: .normal)
		}
	}
	
	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func action(_ sender: Any) {
		self.errorMessageLabel.text = nil
		
		guard emailTextField.text != nil && passwordTextField.text != nil else {
			self.errorMessageLabel.text = NSLocalizedString("Username & password required.", comment: "Credentials Error")
			return
		}
	
		startAnimatingActivityIndicator()
		disableNavigation()
		
		// When you fill in the email address via auto-complete it adds extra whitespace
		let emailAddress = emailTextField.text?.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials.basic(username: emailAddress ?? "", password: passwordTextField.text ?? "")
		Account.validateCredentials(type: .feedbin, credentials: credentials) { result in
			
			self.stopAnimtatingActivityIndicator()
			self.enableNavigation()
			
			switch result {
			case .success(let authenticated):
				if (authenticated != nil) {
					var newAccount = false
					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					}
					
					do {
						
						do {
							try self.account?.removeCredentials()
						} catch {}
						try self.account?.storeCredentials(credentials)
						
						if newAccount {
							self.account?.refreshAll() { result in
								switch result {
								case .success:
									break
								case .failure(let error):
									self.presentError(error)
								}
							}
						}
						
						self.dismiss(animated: true, completion: nil)
						self.delegate?.dismiss()
					} catch {
						self.errorMessageLabel.text = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
					}
				} else {
					self.errorMessageLabel.text = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
				}
			case .failure:
				self.errorMessageLabel.text = NSLocalizedString("Network error. Try again later.", comment: "Credentials Error")
			}
			
		}
	}
	
	private func enableNavigation() {
		self.cancelBarButtonItem.isEnabled = true
		self.actionButton.isEnabled = true
	}
	
	private func disableNavigation() {
		cancelBarButtonItem.isEnabled = false
		actionButton.isEnabled = false
	}
	
	private func startAnimatingActivityIndicator() {
		activityIndicator.isHidden = false
		activityIndicator.startAnimating()
	}
	
	private func stopAnimtatingActivityIndicator() {
		self.activityIndicator.isHidden = true
		self.activityIndicator.stopAnimating()
	}
		
}

extension FeedbinAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
