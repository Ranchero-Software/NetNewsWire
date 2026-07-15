//
//  MinifluxAccountViewController.swift
//  NetNewsWire-iOS
//
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
	@IBOutlet var authModeSegmentedControl: UISegmentedControl!
	@IBOutlet var usernameTextField: UITextField!
	@IBOutlet var passwordTextField: UITextField!
	@IBOutlet var apiURLTextField: UITextField!
	@IBOutlet var apiTokenTextField: UITextField!
	@IBOutlet var showHideButton: UIButton!
	@IBOutlet var actionButton: UIButton!
	@IBOutlet var footerLabel: UILabel!
	@IBOutlet var signUpButton: UIButton!

	weak var account: Account?
	weak var delegate: AddAccountDismissDelegate?

	// The API URL row is deliberately last: the rows hidden by auth mode are
	// always interior, so the inset-grouped section keeps its rounded bottom
	// on a visible row.
	private static let authModeRow = 0
	private static let usernameRow = 1
	private static let passwordRow = 2
	private static let apiTokenRow = 3
	private static let apiURLRow = 4

	private var isTokenMode: Bool {
		authModeSegmentedControl.selectedSegmentIndex == 1
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Miniflux"
		setupFooter()

		activityIndicator.isHidden = true
		usernameTextField.delegate = self
		passwordTextField.delegate = self
		apiURLTextField.delegate = self
		apiTokenTextField.delegate = self

		if let account, let credentials = try? retrieveCredentialsForAccount(for: account) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			if credentials.type == .minifluxAPIToken {
				authModeSegmentedControl.selectedSegmentIndex = 1
				apiTokenTextField.text = credentials.secret
			} else {
				authModeSegmentedControl.selectedSegmentIndex = 0
				usernameTextField.text = credentials.username
				passwordTextField.text = credentials.secret
			}
			if let endpointURL = account.endpointURL {
				apiURLTextField.text = endpointURL.absoluteString
			}
		} else {
			authModeSegmentedControl.selectedSegmentIndex = 0
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: usernameTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: passwordTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: apiURLTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: apiTokenTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}

	private func setupFooter() {
		footerLabel.text = NSLocalizedString("Sign in to your Miniflux instance and sync your feeds across your devices. Your credentials will be encrypted and stored in Keychain.\n\nDon’t have a Miniflux instance?", comment: "Miniflux")
		signUpButton.setTitle(NSLocalizedString("Find Out More", comment: "Find Out More"), for: .normal)
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = Assets.Images.accountMiniflux
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		guard indexPath.section == 0 else {
			return super.tableView(tableView, heightForRowAt: indexPath)
		}

		switch indexPath.row {
		case Self.usernameRow, Self.passwordRow:
			return isTokenMode ? 0 : UITableView.automaticDimension
		case Self.apiTokenRow:
			return isTokenMode ? UITableView.automaticDimension : 0
		default:
			return super.tableView(tableView, heightForRowAt: indexPath)
		}
	}

	@IBAction func authModeChanged(_ sender: UISegmentedControl) {
		// Re-evaluate row heights without reloading — reloading static cells
		// detaches their content views.
		tableView.performBatchUpdates(nil)
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
		guard validateDataEntry(), let url = normalizedAPIURL() else {
			return
		}

		let credentials: Credentials
		if isTokenMode {
			let apiToken = (apiTokenTextField.text ?? "").trimmingWhitespace
			credentials = Credentials(type: .minifluxAPIToken, username: "", secret: apiToken)
		} else {
			let trimmedUsername = (usernameTextField.text ?? "").trimmingWhitespace
			let password = passwordTextField.text ?? ""
			credentials = Credentials(type: .minifluxBasic, username: trimmedUsername, secret: password)
		}

		Task { @MainActor in
			startAnimatingActivityIndicator()
			disableNavigation()

			@MainActor func stopAnimation() {
				stopAnimatingActivityIndicator()
				enableNavigation()
			}

			do {
				let validatedCredentials = try await Account.validateCredentials(type: .miniflux, credentials: credentials, endpoint: url)
				stopAnimation()

				guard let validatedCredentials else {
					showError(NSLocalizedString("Invalid credentials.", comment: "Credentials Error"))
					return
				}

				guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, username: validatedCredentials.username) else {
					showError(NSLocalizedString("There is already an account of that type with that username created.", comment: "Duplicate Error"))
					return
				}

				guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, endpointURL: url) else {
					showError(NSLocalizedString("There is already a Miniflux account for this server.", comment: "Duplicate Error"))
					return
				}

				if account == nil {
					account = AccountManager.shared.createAccount(type: .miniflux)
				}

				account?.endpointURL = url

				do {
					// Remove any credentials of the other type so a stale token or
					// password doesn't take precedence after switching auth modes.
					let staleCredentialsType: CredentialsType = validatedCredentials.type == .minifluxAPIToken ? .minifluxBasic : .minifluxAPIToken
					try? account?.removeCredentials(type: staleCredentialsType)
					try account?.storeCredentials(validatedCredentials)
				} catch {
					showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
					return
				}

				// Dismiss immediately rather than waiting for the initial sync to finish —
				// this deliberately differs from the other account types, whose long initial
				// refreshAll() keeps the add-account flow on screen.
				let accountToRefresh = account
				dismiss(animated: true, completion: nil)
				delegate?.dismiss()

				Task {
					do {
						try await accountToRefresh?.refreshAll()
					} catch {
						ErrorHandler.log(error)
					}
				}
			} catch {
				stopAnimation()
				showError(error.localizedDescription)
			}
		}
	}

	private func retrieveCredentialsForAccount(for account: Account) throws -> Credentials? {
		if let tokenCredentials = try account.retrieveCredentials(type: .minifluxAPIToken) {
			return tokenCredentials
		}
		return try account.retrieveCredentials(type: .minifluxBasic)
	}

	private func validateDataEntry() -> Bool {
		guard apiURLTextField.hasText, normalizedAPIURL() != nil else {
			showError(NSLocalizedString("Invalid API URL.", comment: "Invalid API URL"))
			return false
		}

		if isTokenMode {
			guard apiTokenTextField.hasText else {
				showError(NSLocalizedString("An API token is required.", comment: "Credentials Error"))
				return false
			}
		} else {
			guard usernameTextField.hasText, passwordTextField.hasText else {
				showError(NSLocalizedString("A username and password are required.", comment: "Credentials Error"))
				return false
			}
		}

		return true
	}

	@IBAction func signUpWithProvider(_ sender: Any) {
		guard let url = URL(string: "https://miniflux.app") else {
			return
		}
		let safari = SFSafariViewController(url: url)
		safari.modalPresentationStyle = .currentContext
		self.present(safari, animated: true, completion: nil)
	}

	private func normalizedAPIURL() -> URL? {
		guard let text = apiURLTextField.text else {
			return nil
		}

		var trimmed = text.trimmingWhitespace
		while trimmed.hasSuffix("/") {
			trimmed.removeLast()
		}
		if trimmed.hasSuffix("/v1") {
			trimmed.removeLast(3)
		}
		while trimmed.hasSuffix("/") {
			trimmed.removeLast()
		}

		guard !trimmed.isEmpty else {
			return nil
		}

		if !trimmed.contains("://") {
			trimmed = "https://" + trimmed
		}

		return URL(string: trimmed)
	}

	@objc func textDidChange(_ note: Notification) {
		actionButton.isEnabled = apiURLTextField.hasText
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
