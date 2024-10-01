//
//  NewsBlurAccountViewController.swift
//  NetNewsWire
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Secrets
import Web
import SafariServices

class NewsBlurAccountViewController: UITableViewController {

	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var usernameTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var showHideButton: UIButton!
	@IBOutlet weak var actionButton: UIButton!
	@IBOutlet weak var footerLabel: UILabel!
	@IBOutlet weak var onepasswordButton: UIBarButtonItem! {
		didSet {
			onepasswordButton.image?.withTintColor(AppAssets.primaryAccentColor)
		}
	}

	weak var account: Account?
	weak var delegate: AddAccountDismissDelegate?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setupFooter()
		activityIndicator.isHidden = true
		usernameTextField.delegate = self
		passwordTextField.delegate = self

		if let account = account, let credentials = try? account.retrieveCredentials(type: .newsBlurBasic) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			usernameTextField.text = credentials.username
			passwordTextField.text = credentials.secret
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: usernameTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: passwordTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}
	
	private func setupFooter() {
		footerLabel.text = NSLocalizedString("Sign in to your NewsBlur account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a NewsBlur account?", comment: "NewsBlur")
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = AppAsset.accountImage(for: .newsBlur)
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
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

		guard let username = usernameTextField.text else {
			showError(NSLocalizedString("Username required.", comment: "Credentials Error"))
			return
		}

		// When you fill in the email address via auto-complete it adds extra whitespace
		let trimmedUsername = username.trimmingCharacters(in: .whitespaces)

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .newsBlur, username: trimmedUsername) else {
			showError(NSLocalizedString("There is already a NewsBlur account with that username created.", comment: "Duplicate Error"))
			return
		}

		let password = passwordTextField.text ?? ""

		startAnimatingActivityIndicator()
		disableNavigation()

		let credentials = Credentials(type: .newsBlurBasic, username: trimmedUsername, secret: password)

		Task { @MainActor in

			var validationDidThrow = false
			var validatedCredentials: Credentials?

			do {
				validatedCredentials = try await Account.validateCredentials(type: .newsBlur, credentials: credentials)
			} catch {
				self.showError(error.localizedDescription)
				validationDidThrow = true
			}

			self.stopAnimatingActivityIndicator()
			self.enableNavigation()

			if validationDidThrow {
				return
			}

			guard let validatedCredentials else {
				self.showError(NSLocalizedString("Invalid username/password combination.", comment: "Credentials Error"))
				return
			}

			if self.account == nil {
				self.account = AccountManager.shared.createAccount(type: .newsBlur)
			}

			do {

				try self.account?.removeCredentials(type: .newsBlurBasic)
				try self.account?.removeCredentials(type: .newsBlurSessionID)
				try self.account?.storeCredentials(credentials)
				try self.account?.storeCredentials(validatedCredentials)

				self.refreshAll()

				self.dismiss(animated: true, completion: nil)
				self.delegate?.dismiss()
			} catch {
				self.showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
			}
		}
	}

	private func refreshAll() {

		Task { @MainActor in
			do {
				try await self.account?.refreshAll()
			} catch {
				self.presentError(error)
			}
		}
	}

	@IBAction func signUpWithProvider(_ sender: Any) {
		let url = URL(string: "https://newsblur.com")!
		let safari = SFSafariViewController(url: url)
		safari.modalPresentationStyle = .currentContext
		self.present(safari, animated: true, completion: nil)
	}
	
	@IBAction func retrievePasswordDetailsFrom1Password(_ sender: Any) {
		OnePasswordExtension.shared().findLogin(forURLString: "newsblur.com", for: self, sender: sender) { [self] loginDictionary, error in
			if let loginDictionary = loginDictionary {
				usernameTextField.text = loginDictionary[AppExtensionUsernameKey] as? String
				passwordTextField.text = loginDictionary[AppExtensionPasswordKey] as? String
				actionButton.isEnabled = !(usernameTextField.text?.isEmpty ?? false) && !(passwordTextField.text?.isEmpty ?? false)
			}
		}
	}

	@objc func textDidChange(_ note: Notification) {
		actionButton.isEnabled = !(usernameTextField.text?.isEmpty ?? false)
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

	private func stopAnimatingActivityIndicator() {
		self.activityIndicator.isHidden = true
		self.activityIndicator.stopAnimating()
	}

}

extension NewsBlurAccountViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
