//
//  FeedbinAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSWeb

class FeedbinAccountViewController: UITableViewController {

	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var emailTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var showHideButton: UIButton!
	@IBOutlet weak var actionButton: UIButton!
	
	weak var account: Account?
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
        super.viewDidLoad()

		activityIndicator.isHidden = true
		emailTextField.delegate = self
		passwordTextField.delegate = self
		
		if let account = account, let credentials = try? account.retrieveCredentials(type: .basic) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			emailTextField.text = credentials.username
			passwordTextField.text = credentials.secret
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: emailTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: passwordTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = AppAssets.image(for: .feedbin)
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func showHidePassword(_ sender: Any) {
		if passwordTextField.isSecureTextEntry {
			passwordTextField.isSecureTextEntry = false
			showHideButton.setTitle("Hide", for: .normal)
		} else {
			passwordTextField.isSecureTextEntry = true
			showHideButton.setTitle("Show", for: .normal)
		}
	}
	
	@IBAction func action(_ sender: Any) {
		
		guard let email = emailTextField.text, let password = passwordTextField.text else {
			showError(NSLocalizedString("Username & password required.", comment: "Credentials Error"))
			return
		}
		resignFirstResponder()
		toggleActivityIndicatorAnimation(visible: true)
		setNavigationEnabled(to: false)
		
		// When you fill in the email address via auto-complete it adds extra whitespace
		let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials(type: .basic, username: trimmedEmail, secret: password)
		Account.validateCredentials(type: .feedbin, credentials: credentials) { result in
			self.toggleActivityIndicatorAnimation(visible: false)
			self.setNavigationEnabled(to: true)
			
			switch result {
			case .success(let credentials):
				if let credentials = credentials {
					var newAccount = false
					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					}
					
					do {
						
						do {
							try self.account?.removeCredentials(type: .basic)
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
						self.showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
					}
				} else {
					self.showError(NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error"))
				}
			case .failure:
				self.showError(NSLocalizedString("Network error. Try again later.", comment: "Credentials Error"))
			}
			
		}
	}
	
	@objc func textDidChange(_ note: Notification) {
		actionButton.isEnabled = !(emailTextField.text?.isEmpty ?? false) && !(passwordTextField.text?.isEmpty ?? false) 
	}
	
	private func showError(_ message: String) {
		presentError(title: NSLocalizedString("Error", comment: "Credentials Error"), message: message)
	}
	
	private func setNavigationEnabled(to value:Bool){
		cancelBarButtonItem.isEnabled = value
		actionButton.isEnabled = value
	}
	
	private func toggleActivityIndicatorAnimation(visible value: Bool){
		activityIndicator.isHidden = !value
		if value {
			activityIndicator.startAnimating()
		} else {
			activityIndicator.stopAnimating()
		}
	}
		
}

extension FeedbinAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == emailTextField {
			passwordTextField.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
			action(self)
		}
		return true
	}
	
}
