//
//  AccountsAddFeedbinWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSWeb
import Secrets

final class AccountsReaderAPIWindowController: NSWindowController {

	private struct CustomHeaderFieldSet {
		let container: NSStackView
		let nameTextField: NSTextField
		let valueTextField: NSTextField
	}

	private struct CustomHeaderValidationError: LocalizedError {
		var errorDescription: String? {
			NSLocalizedString("Custom header names and values are required. Header names must be valid HTTP field names.", comment: "FreshRSS Custom HTTP Header Error")
		}
	}

	@IBOutlet var titleImageView: NSImageView!
	@IBOutlet var titleLabel: NSTextField!

	@IBOutlet var gridView: NSGridView!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var usernameTextField: NSTextField!
	@IBOutlet var apiURLTextField: NSTextField!
	@IBOutlet var passwordTextField: NSSecureTextField!
	@IBOutlet var createAccountButton: NSButton!
	@IBOutlet var errorMessageLabel: NSTextField!
	@IBOutlet var actionButton: NSButton!
	@IBOutlet var noAccountTextField: NSTextField!

	var account: Account?
	var accountType: AccountType?

	private weak var hostWindow: NSWindow?
	private var customHeaderStackView: NSStackView?
	private var customHeaderFieldSets = [CustomHeaderFieldSet]()
	private var baseWindowFrame: NSRect?
	private let customHeaderAdditionalWidth: CGFloat = 0
	private let customHeaderSectionHeight: CGFloat = 37
	private let customHeaderRowHeight: CGFloat = 91
	private let customHeaderFieldWidth: CGFloat = 200

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsReaderAPI"))
	}

	override func windowDidLoad() {
		if let accountType = accountType {
			switch accountType {
			case .freshRSS:
				titleImageView.image = Assets.Images.accountFreshRSS
				titleLabel.stringValue = NSLocalizedString("Sign in to your FreshRSS account.", comment: "FreshRSS")
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a FreshRSS instance?", comment: "No FreshRSS")
				createAccountButton.title = NSLocalizedString("Find out more", comment: "No FreshRSS Button")
				apiURLTextField.placeholderString = NSLocalizedString("https://fresh.rss.net/api/greader.php", comment: "FreshRSS API Helper")
			case .inoreader:
				titleImageView.image = Assets.Images.accountInoreader
				titleLabel.stringValue = NSLocalizedString("Sign in to your Inoreader account.", comment: "Inoreader")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have an Inoreader account?", comment: "No Inoreader")
			case .bazQux:
				titleImageView.image = Assets.Images.accountBazQux
				titleLabel.stringValue = NSLocalizedString("Sign in to your BazQux account.", comment: "BazQux")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a BazQux account?", comment: "No BazQux")
			case .theOldReader:
				titleImageView.image = Assets.Images.accountTheOldReader
				titleLabel.stringValue = NSLocalizedString("Sign in to your The Old Reader account.", comment: "The Old Reader")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a The Old Reader account?", comment: "No OldReader")
			default:
				break
			}
		}

		baseWindowFrame = window?.frame
		if let account = account, let credentials = try? account.retrieveCredentials(type: .readerBasic) {
			usernameTextField.stringValue = credentials.username
			apiURLTextField.stringValue = account.endpointURL?.absoluteString ?? ""
			actionButton.title = NSLocalizedString("Update", comment: "Update")
			if accountType == .freshRSS {
				let customHeaders = (try? account.retrieveReaderAPICustomHTTPHeaders()) ?? []
				addCustomHeaderControls(customHeaders: customHeaders)
			}
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
			if accountType == .freshRSS {
				addCustomHeaderControls(customHeaders: [])
			}
		}

		resizeWindowForCustomHeaders()
		enableAutofill()
		usernameTextField.becomeFirstResponder()
	}

	// MARK: API

	func runSheetOnWindow(_ hostWindow: NSWindow, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		guard let window else {
			return
		}

		self.hostWindow = hostWindow
		hostWindow.beginSheet(window, completionHandler: completion)
	}

	// MARK: Actions

	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}

	@IBAction func action(_ sender: Any) {
		self.errorMessageLabel.stringValue = ""

		guard !usernameTextField.stringValue.isEmpty && !passwordTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username, password & API URL are required.", comment: "Credentials Error")
			return
		}

		guard let accountType = accountType, !(accountType == .freshRSS && apiURLTextField.stringValue.isEmpty) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username, password & API URL are required.", comment: "Credentials Error")
			return
		}

		let trimmedUsername = usernameTextField.stringValue.trimmingWhitespace

		let apiURL: URL
		switch accountType {
		case .freshRSS:
			guard let inputURL = URL(string: apiURLTextField.stringValue.trimmingWhitespace) else {
				self.errorMessageLabel.stringValue = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
				return
			}
			apiURL = inputURL
		case .inoreader:
			apiURL =  URL(string: ReaderAPIVariant.inoreader.host)!
		case .bazQux:
			apiURL =  URL(string: ReaderAPIVariant.bazQux.host)!
		case .theOldReader:
			apiURL =  URL(string: ReaderAPIVariant.theOldReader.host)!
		default:
			self.errorMessageLabel.stringValue = NSLocalizedString("Unrecognized account type.", comment: "Bad account type")
			return
		}

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: accountType, username: trimmedUsername, endpoint: apiURL) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("There is already an account of this type with that username created.", comment: "Duplicate Error")
			return
		}

		let customHTTPHeaders: [ReaderAPICustomHTTPHeader]
		do {
			customHTTPHeaders = try validatedCustomHTTPHeaders()
		} catch {
			self.errorMessageLabel.stringValue = error.localizedDescription
			return
		}

		Task { @MainActor in
			actionButton.isEnabled = false
			progressIndicator.isHidden = false
			progressIndicator.startAnimation(self)

			@MainActor func stopAnimation() {
				actionButton.isEnabled = true
				progressIndicator.isHidden = true
				progressIndicator.stopAnimation(self)
			}

			let credentials = Credentials(type: .readerBasic, username: trimmedUsername, secret: passwordTextField.stringValue)
			do {
				let validatedCredentials = try await Account.validateCredentials(type: accountType, credentials: credentials, endpoint: apiURL, customHTTPHeaders: customHTTPHeaders)
				stopAnimation()

				guard let validatedCredentials else {
					errorMessageLabel.stringValue = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
					return
				}

				if account == nil {
					account = AccountManager.shared.createAccount(type: accountType)
				}

				do {
					account?.endpointURL = apiURL

					try account?.storeCredentials(credentials)
					try account?.storeCredentials(validatedCredentials)
					try account?.storeReaderAPICustomHTTPHeaders(customHTTPHeaders)

					hostWindow?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)

					account?.triggerRefreshAll()
				} catch {
					errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}

			} catch {
				stopAnimation()
				errorMessageLabel.stringValue = error.localizedDescription
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {
		switch accountType {
		case .freshRSS:
			NSWorkspace.shared.open(URL(string: "https://freshrss.org")!)
		case .inoreader:
			NSWorkspace.shared.open(URL(string: "https://www.inoreader.com")!)
		case .bazQux:
			NSWorkspace.shared.open(URL(string: "https://bazqux.com")!)
		case .theOldReader:
			NSWorkspace.shared.open(URL(string: "https://theoldreader.com")!)
		default:
			return
		}
	}

	// MARK: Autofill
	func enableAutofill() {
		usernameTextField.contentType = .username
		passwordTextField.contentType = .password
	}

}

private extension AccountsReaderAPIWindowController {

	func addCustomHeaderControls(customHeaders: [ReaderAPICustomHTTPHeader]) {
		guard customHeaderStackView == nil else {
			return
		}

		let label = NSTextField(labelWithString: NSLocalizedString("Headers:", comment: "FreshRSS Custom HTTP Headers"))
		label.alignment = .right

		let stackView = NSStackView()
		stackView.orientation = .vertical
		stackView.alignment = .left
		stackView.spacing = 6
		stackView.translatesAutoresizingMaskIntoConstraints = false
		customHeaderStackView = stackView

		gridView.addRow(with: [label, stackView])
		gridView.row(at: gridView.numberOfRows - 1).topPadding = 6

		for customHeader in customHeaders {
			appendCustomHeaderFieldSet(name: customHeader.name, value: customHeader.value)
		}

		addCustomHeaderButton()
	}

	func addCustomHeaderButton() {
		guard let customHeaderStackView else {
			return
		}

		let button = NSButton(title: NSLocalizedString("Add Custom Header", comment: "FreshRSS Custom HTTP Header Button"), target: self, action: #selector(addCustomHeader(_:)))
		button.bezelStyle = .rounded
		button.controlSize = .small
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
		button.setContentHuggingPriority(.required, for: .horizontal)
		customHeaderStackView.addArrangedSubview(button)
	}

	@objc func addCustomHeader(_ sender: Any) {
		appendCustomHeaderFieldSet(name: "", value: "")
		resizeWindowForCustomHeaders()
	}

	func appendCustomHeaderFieldSet(name: String, value: String) {
		guard let customHeaderStackView else {
			return
		}

		let nameTextField = NSTextField()
		nameTextField.placeholderString = NSLocalizedString("Header name", comment: "FreshRSS Custom HTTP Header Name")
		nameTextField.stringValue = name
		nameTextField.translatesAutoresizingMaskIntoConstraints = false
		nameTextField.cell?.usesSingleLineMode = true
		nameTextField.cell?.lineBreakMode = .byTruncatingTail
		nameTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		nameTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)

		let valueTextField = NSTextField()
		valueTextField.placeholderString = NSLocalizedString("Header value", comment: "FreshRSS Custom HTTP Header Value")
		valueTextField.stringValue = value
		valueTextField.translatesAutoresizingMaskIntoConstraints = false
		valueTextField.cell?.usesSingleLineMode = true
		valueTextField.cell?.lineBreakMode = .byTruncatingTail
		valueTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		valueTextField.setContentHuggingPriority(.defaultLow, for: .horizontal)

		let removeButton = NSButton(title: "", target: self, action: #selector(removeCustomHeader(_:)))
		removeButton.image = NSImage(systemSymbolName: "minus.circle", accessibilityDescription: NSLocalizedString("Remove Custom Header", comment: "FreshRSS Remove Custom HTTP Header"))
		removeButton.title = NSLocalizedString("Remove Header", comment: "FreshRSS Remove Custom HTTP Header Button")
		removeButton.imagePosition = .imageLeading
		removeButton.bezelStyle = .rounded
		removeButton.isBordered = false
		removeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
		removeButton.setContentHuggingPriority(.required, for: .horizontal)

		let fieldsStackView = NSStackView(views: [nameTextField, valueTextField, removeButton])
		fieldsStackView.orientation = .vertical
		fieldsStackView.alignment = .leading
		fieldsStackView.spacing = 4
		fieldsStackView.translatesAutoresizingMaskIntoConstraints = false
		fieldsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

		NSLayoutConstraint.activate([
			nameTextField.widthAnchor.constraint(equalToConstant: customHeaderFieldWidth),
			valueTextField.widthAnchor.constraint(equalToConstant: customHeaderFieldWidth),
			fieldsStackView.widthAnchor.constraint(equalToConstant: customHeaderFieldWidth)
		])

		if let addButton = customHeaderStackView.arrangedSubviews.last as? NSButton {
			customHeaderStackView.insertArrangedSubview(fieldsStackView, at: max(customHeaderStackView.arrangedSubviews.count - 1, 0))
			addButton.nextKeyView = nameTextField
		} else {
			customHeaderStackView.addArrangedSubview(fieldsStackView)
		}

		removeButton.target = self
		removeButton.action = #selector(removeCustomHeader(_:))
		customHeaderFieldSets.append(CustomHeaderFieldSet(container: fieldsStackView, nameTextField: nameTextField, valueTextField: valueTextField))
	}

	@objc func removeCustomHeader(_ sender: NSButton) {
		guard let customHeaderStackView, let fieldSet = customHeaderFieldSets.first(where: { sender.isDescendant(of: $0.container) }) else {
			return
		}

		customHeaderStackView.removeArrangedSubview(fieldSet.container)
		fieldSet.container.removeFromSuperview()
		customHeaderFieldSets.removeAll { $0.container == fieldSet.container }
		resizeWindowForCustomHeaders()
	}

	func resizeWindowForCustomHeaders() {
		guard let window, let baseWindowFrame else {
			return
		}

		let additionalHeight = customHeaderStackView == nil ? 0 : customHeaderSectionHeight + (CGFloat(customHeaderFieldSets.count) * customHeaderRowHeight)
		let additionalWidth = customHeaderStackView == nil ? 0 : customHeaderAdditionalWidth
		var frame = baseWindowFrame
		frame.size.height += additionalHeight
		frame.origin.y -= additionalHeight
		frame.size.width += additionalWidth
		frame.origin.x -= additionalWidth / 2
		window.setFrame(frame, display: true)
	}

	func validatedCustomHTTPHeaders() throws -> [ReaderAPICustomHTTPHeader] {
		guard accountType == .freshRSS else {
			return []
		}

		var customHeaders = [ReaderAPICustomHTTPHeader]()
		for fieldSet in customHeaderFieldSets {
			let name = fieldSet.nameTextField.stringValue
			let value = fieldSet.valueTextField.stringValue

			if name.trimmingWhitespace.isEmpty && value.trimmingWhitespace.isEmpty {
				continue
			}

			guard let customHeader = ReaderAPICustomHTTPHeader(name: name, value: value) else {
				throw CustomHeaderValidationError()
			}

			customHeaders.append(customHeader)
		}

		return customHeaders
	}

}
