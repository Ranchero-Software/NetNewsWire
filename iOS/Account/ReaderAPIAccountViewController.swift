//
//  ReaderAPIAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 25/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Secrets
import RSWeb
import SafariServices

class ReaderAPIAccountViewController: UITableViewController {

	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var usernameTextField: UITextField!
	@IBOutlet weak var passwordTextField: UITextField!
	@IBOutlet weak var apiURLTextField: UITextField!
	@IBOutlet weak var showHideButton: UIButton!
	@IBOutlet weak var actionButton: UIButton!
	@IBOutlet weak var footerLabel: UILabel!
	@IBOutlet weak var signUpButton: UIButton!
	
	weak var account: Account?
	var accountType: AccountType?
	weak var delegate: AddAccountDismissDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		setupFooter()

		activityIndicator.isHidden = true
		usernameTextField.delegate = self
		passwordTextField.delegate = self
		
		if let unwrappedAcount = account,
		   let credentials = try? retrieveCredentialsForAccount(for: unwrappedAcount) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			usernameTextField.text = credentials.username
			passwordTextField.text = credentials.secret
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}
		
		if let unwrappedAccountType = accountType {
			switch unwrappedAccountType {
			case .freshRSS:
				title = NSLocalizedString("FreshRSS", comment: "FreshRSS")
			case .inoreader:
				title = NSLocalizedString("InoReader", comment: "InoReader")
			case .bazQux:
				title = NSLocalizedString("BazQux", comment: "BazQux")
			case .theOldReader:
				title = NSLocalizedString("The Old Reader", comment: "The Old Reader")
			default:
				title = ""
			}
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: usernameTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: passwordTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
    }
	
	private func setupFooter() {
		switch accountType {
			case .bazQux:
				footerLabel.text = NSLocalizedString("Sign in to your BazQux account and sync your subscriptions across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon't have a BazQux account?", comment: "BazQux")
				signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "BazQux SignUp"), for: .normal)
			case .inoreader:
				footerLabel.text = NSLocalizedString("Sign in to your InoReader account and sync your subscriptions across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon't have an InoReader account?", comment: "InoReader")
				signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "InoReader SignUp"), for: .normal)
			case .theOldReader:
				footerLabel.text = NSLocalizedString("Sign in to your The Old Reader account and sync your subscriptions across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon't have a The Old Reader account?", comment: "TOR")
				signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "TOR SignUp"), for: .normal)
			case .freshRSS:
				footerLabel.text = NSLocalizedString("Sign in to your FreshRSS instance and sync your subscriptions across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon't have an FreshRSS instance?", comment: "FreshRSS")
				signUpButton.setTitle(NSLocalizedString("Find Out More", comment: "FreshRSS SignUp"), for: .normal)
			default:
				return
		}
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
			switch accountType {
			case .freshRSS:
				return 3
			default:
				return 2
			}
		default:
			return 1
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
		guard validateDataEntry(), let type = accountType else {
			return
		}
		
		let username = usernameTextField.text!
		let password = passwordTextField.text!
		let url = apiURL()!
		
		// When you fill in the email address via auto-complete it adds extra whitespace
		let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
		
		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: type, username: trimmedUsername) else {
			showError(NSLocalizedString("There is already an account of that type with that username created.", comment: "Duplicate Error"))
			return
		}

		startAnimatingActivityIndicator()
		disableNavigation()

		let credentials = Credentials(type: .readerBasic, username: trimmedUsername, secret: password)
		Account.validateCredentials(type: type, credentials: credentials, endpoint: url) { result in

			self.stopAnimatingActivityIndicator()
			self.enableNavigation()

			switch result {
			case .success(let validatedCredentials):
				if let validatedCredentials = validatedCredentials {

					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: type)
					}

					do {
						self.account?.endpointURL = url
						
						try? self.account?.removeCredentials(type: .readerBasic)
						try? self.account?.removeCredentials(type: .readerAPIKey)
						try self.account?.storeCredentials(credentials)
						try self.account?.storeCredentials(validatedCredentials)

						self.dismiss(animated: true, completion: nil)
						
						self.account?.refreshAll() { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								self.showError(NSLocalizedString(error.localizedDescription, comment: "Accoount Refresh Error"))
							}
						}
						
						self.delegate?.dismiss()
					} catch {
						self.showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
					}
				} else {
					self.showError(NSLocalizedString("Invalid username/password combination.", comment: "Credentials Error"))
				}
			case .failure(let error):
				self.showError(error.localizedDescription)
			}

		}
	}
	
	private func retrieveCredentialsForAccount(for account: Account) throws -> Credentials? {
		switch accountType {
		case .bazQux, .inoreader, .theOldReader, .freshRSS:
			return try account.retrieveCredentials(type: .readerBasic)
		default:
			return nil
		}
	}
	
	private func headerViewImage() -> UIImage? {
		if let accountType = accountType {
			switch accountType {
				case .bazQux:
					return AppAssets.accountBazQuxImage
				case .inoreader:
					return AppAssets.accountInoreaderImage
				case .theOldReader:
					return AppAssets.accountTheOldReaderImage
				case .freshRSS:
					return AppAssets.accountFreshRSSImage
				default:
					return nil
			}
		}
		return nil
	}
  
	private func validateDataEntry() -> Bool {
		switch accountType {
		case .freshRSS:
			if !usernameTextField.hasText || !passwordTextField.hasText || !apiURLTextField.hasText {
				showError(NSLocalizedString("Username, password, and API URL are required.", comment: "Credentials Error"))
				return false
			}
			guard let _ = URL(string: apiURLTextField.text!) else {
				showError(NSLocalizedString("Invalid API URL.", comment: "Invalid API URL"))
				return false
			}
		default:
			if !usernameTextField.hasText || !passwordTextField.hasText {
				showError(NSLocalizedString("Username and password are required.", comment: "Credentials Error"))
				return false
			}
		}
		return true
	}
	
	@IBAction func signUpWithProvider(_ sender: Any) {
		var url: URL!
		switch accountType {
			case .bazQux:
				url = URL(string: "https://bazqux.com")!
			case .inoreader:
				url = URL(string: "https://www.inoreader.com")!
			case .theOldReader:
				url = URL(string: "https://theoldreader.com")!
			case .freshRSS:
				url = URL(string: "https://freshrss.org")!
			default:
				return
		}
		let safari = SFSafariViewController(url: url)
		safari.modalPresentationStyle = .currentContext
		self.present(safari, animated: true, completion: nil)
	}
	
	private func apiURL() -> URL? {
		switch accountType {
		case .freshRSS:
			return URL(string: apiURLTextField.text!)!
		case .inoreader:
			return URL(string: ReaderAPIVariant.inoreader.host)!
		case .bazQux:
			return URL(string: ReaderAPIVariant.bazQux.host)!
		case .theOldReader:
			return URL(string: ReaderAPIVariant.theOldReader.host)!
		default:
			return nil
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

extension ReaderAPIAccountViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
