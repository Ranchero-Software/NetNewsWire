//
//  MinifluxAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Ingmar Stein on 6/18/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import RSCore
import RSWeb
import Account
import Secrets

final class MinifluxAccountViewController: UITableViewController {

	@IBOutlet var activityIndicator: UIActivityIndicatorView!
	@IBOutlet var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet var apiURLTextField: UITextField!
	@IBOutlet var apiKeyTextField: UITextField!
	@IBOutlet var showHideButton: UIButton!
	@IBOutlet var actionButton: UIButton!
	@IBOutlet var footerLabel: UILabel!
	@IBOutlet var signUpButton: UIButton!

	weak var account: Account?
	var accountType: AccountType?
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		setupFooter()

		activityIndicator.isHidden = true
		apiURLTextField.delegate = self
		apiKeyTextField.delegate = self

		title = "Miniflux"

		if let unwrappedAccount = account,
		   let credentials = try? retrieveCredentialsForAccount(for: unwrappedAccount) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			apiURLTextField.text = unwrappedAccount.endpointURL?.absoluteString ?? ""
			apiKeyTextField.text = credentials.secret
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}

		apiURLTextField.placeholder = NSLocalizedString("API URL: https://miniflux.example.com", comment: "Miniflux API URL Helper")

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: apiURLTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: apiKeyTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}

	private func setupFooter() {
		footerLabel.text = NSLocalizedString("Sign in to your Miniflux instance and sync your feeds across your devices. Your API key will be encrypted and stored in Keychain.\n\nDon't have a Miniflux instance?", comment: "Miniflux")
		signUpButton.setTitle(NSLocalizedString("Find Out More", comment: "Find Out More"), for: .normal)
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = headerViewImage()
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			return 2
		default:
			return 1
		}
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
	}

	@IBAction func showHidePassword(_ sender: Any) {
		if apiKeyTextField.isSecureTextEntry {
			apiKeyTextField.isSecureTextEntry = false
			showHideButton.setTitle("Hide", for: .normal)
		} else {
			apiKeyTextField.isSecureTextEntry = true
			showHideButton.setTitle("Show", for: .normal)
		}
	}

	@IBAction func action(_ sender: Any) {
		guard validateDataEntry() else {
			return
		}

		let apiKey = apiKeyTextField.text!
		let url = apiURL()!

		let trimmedAPIKey = apiKey.trimmingWhitespace

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, endpointURL: url) else {
			showError(NSLocalizedString("There is already a Miniflux account with that URL created.", comment: "Duplicate Error"))
			return
		}

		Task { @MainActor in
			startAnimatingActivityIndicator()
			disableNavigation()

			@MainActor func stopAnimation() {
				stopAnimatingActivityIndicator()
				enableNavigation()
			}

			let credentials = Credentials(type: .minifluxAPIKey, username: trimmedAPIKey, secret: trimmedAPIKey)
			do {
				let validatedCredentials = try await Account.validateCredentials(type: .miniflux, credentials: credentials, endpoint: url)
				stopAnimation()

				if let validatedCredentials {
					if account == nil {
						account = AccountManager.shared.createAccount(type: .miniflux)
					}

					do {
						account?.endpointURL = url

						try account?.storeCredentials(validatedCredentials)

						dismiss(animated: true, completion: nil)

						do {
							try await account?.refreshAll()
						} catch {
							showError(NSLocalizedString(error.localizedDescription, comment: "Account Refresh Error"))
						}

						delegate?.dismiss()
					} catch {
						showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
					}
				} else {
					showError(NSLocalizedString("Invalid API key.", comment: "Credentials Error"))
				}
			} catch {
				stopAnimation()
				if case AccountError.urlNotFound = error {
					showError(NSLocalizedString("The API URL couldn't be found. Please check the URL.", comment: "API URL not found"))
				} else {
					showError(error.localizedDescription)
				}
			}
		}
	}

	private func retrieveCredentialsForAccount(for account: Account) throws -> Credentials? {
		try account.retrieveCredentials(type: .minifluxAPIKey)
	}

	private func headerViewImage() -> UIImage? {
		Assets.Images.accountMiniflux
	}

	private func validateDataEntry() -> Bool {
		if !apiURLTextField.hasText || !apiKeyTextField.hasText {
			showError(NSLocalizedString("API URL and API Key are required.", comment: "Credentials Error"))
			return false
		}
		guard URL(string: apiURLTextField.text!) != nil else {
			showError(NSLocalizedString("Invalid API URL.", comment: "Invalid API URL"))
			return false
		}
		return true
	}

	@IBAction func signUpWithProvider(_ sender: Any) {
		let url = URL(string: "https://miniflux.app")!
		let safari = SFSafariViewController(url: url)
		safari.modalPresentationStyle = .currentContext
		self.present(safari, animated: true, completion: nil)
	}

	private func apiURL() -> URL? {
		URL(string: apiURLTextField.text!.trimmingWhitespace)!
	}

	@objc func textDidChange(_ note: Notification) {
		actionButton.isEnabled = !(apiURLTextField.text?.isEmpty ?? false)
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

extension MinifluxAccountViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
}
