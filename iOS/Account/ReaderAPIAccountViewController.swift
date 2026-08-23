//
//  ReaderAPIAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 25/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import RSCore
import RSWeb
import Account
import Secrets

final class ReaderAPIAccountViewController: UITableViewController {
	@IBOutlet var activityIndicator: UIActivityIndicatorView!
	@IBOutlet var cancelBarButtonItem: UIBarButtonItem!
	@IBOutlet var usernameTextField: UITextField!
	@IBOutlet var passwordTextField: UITextField!
	@IBOutlet var apiURLTextField: UITextField!
	@IBOutlet var showHideButton: UIButton!
	@IBOutlet var actionButton: UIButton!
	@IBOutlet var footerLabel: UILabel!
	@IBOutlet var signUpButton: UIButton!

	weak var account: Account?
	var accountType: AccountType?
	weak var delegate: AddAccountDismissDelegate?

	private struct CustomHeaderInput {
		var name: String
		var value: String
	}

	private static let customHeaderCellIdentifier = "CustomHeaderCell"
	private static let addCustomHeaderCellIdentifier = "AddCustomHeaderCell"
	private var customHeaderInputs = [CustomHeaderInput]()

    override func viewDidLoad() {
        super.viewDidLoad()
		setupFooter()

		activityIndicator.isHidden = true
		usernameTextField.delegate = self
		passwordTextField.delegate = self

		if let unwrappedAccount = account,
		   let credentials = try? retrieveCredentialsForAccount(for: unwrappedAccount) {
			actionButton.setTitle(NSLocalizedString("Update Credentials", comment: "Update Credentials"), for: .normal)
			actionButton.isEnabled = true
			usernameTextField.text = credentials.username
			passwordTextField.text = credentials.secret
			apiURLTextField.text = unwrappedAccount.endpointURL?.absoluteString
			let customHeaders = (try? unwrappedAccount.retrieveReaderAPICustomHTTPHeaders()) ?? []
			customHeaderInputs = customHeaders.map { CustomHeaderInput(name: $0.name, value: $0.value) }
		} else {
			actionButton.setTitle(NSLocalizedString("Add Account", comment: "Add Account"), for: .normal)
		}

		if let unwrappedAccountType = accountType {
			switch unwrappedAccountType {
			case .freshRSS:
				title = "FreshRSS"
				apiURLTextField.placeholder = NSLocalizedString("API URL: https://fresh.rss.net/api/greader.php", comment: "FreshRSS API Helper")
			case .inoreader:
				title = "Inoreader"
			case .bazQux:
				title = "BazQux"
			case .theOldReader:
				title = "The Old Reader"
			default:
				title = ""
			}
		}

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: usernameTextField)
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: passwordTextField)

		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		tableView.register(CustomHTTPHeaderCell.self, forCellReuseIdentifier: Self.customHeaderCellIdentifier)
		tableView.register(AddCustomHTTPHeaderCell.self, forCellReuseIdentifier: Self.addCustomHeaderCellIdentifier)

    }

	private func setupFooter() {
		switch accountType {
		case .bazQux:
			footerLabel.text = NSLocalizedString("Sign in to your BazQux account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a BazQux account?", comment: "BazQux")
			signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "Sign Up"), for: .normal)
		case .inoreader:
			footerLabel.text = NSLocalizedString("Sign in to your Inoreader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an Inoreader account?", comment: "Inoreader")
			signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "Sign Up"), for: .normal)
		case .theOldReader:
			footerLabel.text = NSLocalizedString("Sign in to your The Old Reader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a The Old Reader account?", comment: "TOR")
			signUpButton.setTitle(NSLocalizedString("Sign Up Here", comment: "Sign Up"), for: .normal)
		case .freshRSS:
			footerLabel.text = NSLocalizedString("Sign in to your FreshRSS instance and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an FreshRSS instance?", comment: "FreshRSS")
			signUpButton.setTitle(NSLocalizedString("Find Out More", comment: "Find Out More"), for: .normal)
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
				return 4 + customHeaderInputs.count
			default:
				return 2
			}
		default:
			return 1
		}
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if accountType == .freshRSS, indexPath.section == 0, indexPath.row > 2 {
			return UITableView.automaticDimension
		}
		return UITableView.automaticDimension
	}

	override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
		if accountType == .freshRSS, indexPath.section == 0, indexPath.row > 2 {
			return 51
		}
		return 44
	}

	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		return 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard accountType == .freshRSS, indexPath.section == 0, indexPath.row > 2 else {
			return super.tableView(tableView, cellForRowAt: indexPath)
		}

		let addHeaderRow = 3 + customHeaderInputs.count
		if indexPath.row == addHeaderRow {
			let cell = tableView.dequeueReusableCell(withIdentifier: Self.addCustomHeaderCellIdentifier, for: indexPath) as! AddCustomHTTPHeaderCell
			cell.configure { [weak self] in
				self?.appendCustomHeader()
			}
			cell.selectionStyle = .default
			return cell
		}

		let headerIndex = indexPath.row - 3
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.customHeaderCellIdentifier, for: indexPath) as! CustomHTTPHeaderCell
		let input = customHeaderInputs[headerIndex]
		cell.configure(name: input.name, value: input.value) { [weak self] name, value in
			self?.customHeaderInputs[headerIndex] = CustomHeaderInput(name: name, value: value)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard accountType == .freshRSS, indexPath.section == 0, indexPath.row == 3 + customHeaderInputs.count else {
			return
		}

		tableView.deselectRow(at: indexPath, animated: true)
		appendCustomHeader()
	}

	private func appendCustomHeader() {
		let insertedRow = 3 + customHeaderInputs.count
		customHeaderInputs.append(CustomHeaderInput(name: "", value: ""))
		tableView.insertRows(at: [IndexPath(row: insertedRow, section: 0)], with: .automatic)
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		accountType == .freshRSS && indexPath.section == 0 && indexPath.row >= 3 && indexPath.row < 3 + customHeaderInputs.count
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete, self.tableView(tableView, canEditRowAt: indexPath) else {
			return
		}
		customHeaderInputs.remove(at: indexPath.row - 3)
		tableView.reloadData()
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
		let customHTTPHeaders = readerAPICustomHTTPHeaders()

		// When you fill in the email address via auto-complete it adds extra whitespace
		let trimmedUsername = username.trimmingWhitespace

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: type, username: trimmedUsername, endpoint: url) else {
			showError(NSLocalizedString("There is already an account of that type with that username created.", comment: "Duplicate Error"))
			return
		}

		Task { @MainActor in
			startAnimatingActivityIndicator()
			disableNavigation()

			@MainActor func stopAnimation() {
				stopAnimatingActivityIndicator()
				enableNavigation()
			}

			let credentials = Credentials(type: .readerBasic, username: trimmedUsername, secret: password)
			do {
				let validatedCredentials = try await Account.validateCredentials(type: type, credentials: credentials, endpoint: url, customHTTPHeaders: customHTTPHeaders)
				stopAnimation()

				if let validatedCredentials {
					if account == nil {
						account = AccountManager.shared.createAccount(type: type)
					}

					do {
						account?.endpointURL = url

						try account?.storeCredentials(credentials)
						try account?.storeCredentials(validatedCredentials)
						try account?.storeReaderAPICustomHTTPHeaders(customHTTPHeaders)

						account?.triggerRefreshAll()

						dismiss(animated: true, completion: nil)
						delegate?.dismiss()
					} catch {
						showError(NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error"))
					}
				} else {
					showError(NSLocalizedString("Invalid username/password combination.", comment: "Credentials Error"))
				}
			} catch {
				stopAnimation()
				showError(error.localizedDescription)
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
		if let accountType {
			switch accountType {
			case .bazQux:
				return Assets.Images.accountBazQux
			case .inoreader:
				return Assets.Images.accountInoreader
			case .theOldReader:
				return Assets.Images.accountTheOldReader
			case .freshRSS:
				return Assets.Images.accountFreshRSS
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
			guard URL(string: apiURLTextField.text!) != nil else {
				showError(NSLocalizedString("Invalid API URL.", comment: "Invalid API URL"))
				return false
			}
			guard customHeaderFieldsAreValid() else {
				showError(NSLocalizedString("Custom header names and values must be valid.", comment: "Custom Headers Error"))
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
			return URL(string: apiURLTextField.text!.trimmingWhitespace)!
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

	private func readerAPICustomHTTPHeaders() -> [ReaderAPICustomHTTPHeader] {
		customHeaderInputs.compactMap { input in
			ReaderAPICustomHTTPHeader(name: input.name, value: input.value)
		}
	}

	private func customHeaderFieldsAreValid() -> Bool {
		for input in customHeaderInputs {
			let trimmedName = input.name.trimmingWhitespace
			let trimmedValue = input.value.trimmingWhitespace

			if trimmedName.isEmpty && trimmedValue.isEmpty {
				continue
			}
			guard ReaderAPICustomHTTPHeader(name: trimmedName, value: trimmedValue) != nil else {
				return false
			}
		}
		return true
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

private final class CustomHTTPHeaderCell: UITableViewCell {

	private let nameTextField = UITextField()
	private let valueTextField = UITextField()
	private var onChange: ((String, String) -> Void)?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	func configure(name: String, value: String, onChange: @escaping (String, String) -> Void) {
		self.onChange = onChange
		nameTextField.text = name
		valueTextField.text = value
	}

	private func setup() {
		selectionStyle = .none

		nameTextField.placeholder = NSLocalizedString("Header Name", comment: "Header Name")
		nameTextField.autocorrectionType = .no
		nameTextField.spellCheckingType = .no
		nameTextField.smartDashesType = .no
		nameTextField.smartInsertDeleteType = .no
		nameTextField.smartQuotesType = .no
		nameTextField.adjustsFontForContentSizeCategory = true
		nameTextField.font = UIFont.preferredFont(forTextStyle: .body)
		nameTextField.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)

		valueTextField.placeholder = NSLocalizedString("Header Value", comment: "Header Value")
		valueTextField.autocorrectionType = .no
		valueTextField.spellCheckingType = .no
		valueTextField.smartDashesType = .no
		valueTextField.smartInsertDeleteType = .no
		valueTextField.smartQuotesType = .no
		valueTextField.adjustsFontForContentSizeCategory = true
		valueTextField.font = UIFont.preferredFont(forTextStyle: .body)
		valueTextField.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)

		let stackView = UIStackView(arrangedSubviews: [nameTextField, valueTextField])
		stackView.axis = .horizontal
		stackView.spacing = 12
		stackView.distribution = .fillEqually
		stackView.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stackView)

		NSLayoutConstraint.activate([
			stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
			stackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
			stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
		])
	}

	@objc private func textDidChange(_ sender: UITextField) {
		onChange?(nameTextField.text ?? "", valueTextField.text ?? "")
	}
}

private final class AddCustomHTTPHeaderCell: UITableViewCell {

	private let addButton = UIButton(type: .system)
	private var onAdd: (() -> Void)?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	func configure(onAdd: @escaping () -> Void) {
		self.onAdd = onAdd
	}

	private func setup() {
		addButton.setTitle(NSLocalizedString("Add Custom Header", comment: "Add Custom Header"), for: .normal)
		addButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
		addButton.contentHorizontalAlignment = .leading
		addButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
		addButton.titleLabel?.adjustsFontForContentSizeCategory = true
		addButton.translatesAutoresizingMaskIntoConstraints = false
		addButton.addTarget(self, action: #selector(addHeader(_:)), for: .touchUpInside)

		contentView.addSubview(addButton)

		NSLayoutConstraint.activate([
			addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
			addButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			addButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
			addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
		])
	}

	@objc private func addHeader(_ sender: UIButton) {
		onAdd?()
	}
}
