//
//  FeedWranglerAccountViewController.swift
//  NetNewsWire
//
//  Created by Jonathan Bennett on 2019-11-24.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSWeb

class FeedWranglerAccountViewController: UITableViewController {

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
		
		if let account = account, let credentials = try? account.retrieveCredentials(type: .feedWranglerBasic) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			emailTextField.text = credentials.username
			passwordTextField.text = credentials.secret
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Update Credentials"), for: .normal)
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
			headerView.imageView.image = AppAssets.image(for: .feedWrangler)
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
			showHideButton.setTitle(NSLocalizedString("Hide", comment: "Button Label"), for: .normal)
		} else {
			passwordTextField.isSecureTextEntry = true
			showHideButton.setTitle(NSLocalizedString("Show", comment: "Button Label"), for: .normal)
		}
	}
	
	@IBAction func action(_ sender: Any) {
		
		guard let email = emailTextField.text, let password = passwordTextField.text else {
			showError(NSLocalizedString("Username & password required.", comment: "Credentials Error"))
			return
		}
	
		startAnimatingActivityIndicator()
		disableNavigation()
		
		// When you fill in the email address via auto-complete it adds extra whitespace
		let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials(type: .feedWranglerBasic, username: trimmedEmail, secret: password)
		Account.validateCredentials(type: .feedWrangler, credentials: credentials) { result in
			
			self.stopAnimtatingActivityIndicator()
			self.enableNavigation()
			
			switch result {
			case .success(let validatedCredentials):
				guard let validatedCredentials = validatedCredentials else {
					self.showError(NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error"))
					return
				}
				
				var newAccount = false
				if self.account == nil {
					self.account = AccountManager.shared.createAccount(type: .feedWrangler)
					newAccount = true
				}
				
				do {
					try self.account?.removeCredentials(type: .feedWranglerBasic)
					try self.account?.removeCredentials(type: .feedWranglerToken)
					try self.account?.storeCredentials(credentials)
					try self.account?.storeCredentials(validatedCredentials)
					
					if newAccount {
						self.account?.refreshAll { result in
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
			case .failure:
				self.showError(NSLocalizedString("Network error. Try again later.", comment: "Credentials Error"))
			}
			
		}
	}
	
	@objc func textDidChange(_ note: Notification) {
		actionButton.isEnabled = !(emailTextField.text?.isEmpty ?? false) && !(passwordTextField.text?.isEmpty ?? false)
	}
	
	private func showError(_ message: String) {
		presentError(title: "Error", message: message)
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

extension FeedWranglerAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
