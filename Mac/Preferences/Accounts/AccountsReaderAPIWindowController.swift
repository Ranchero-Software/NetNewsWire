//
//  AccountsAddFeedbinWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import Web
import Secrets
import ReaderAPI

class AccountsReaderAPIWindowController: NSWindowController {

	@IBOutlet weak var titleImageView: NSImageView!
	@IBOutlet weak var titleLabel: NSTextField!
	
	@IBOutlet weak var gridView: NSGridView!
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var usernameTextField: NSTextField!
	@IBOutlet weak var apiURLTextField: NSTextField!
	@IBOutlet weak var passwordTextField: NSSecureTextField!
	@IBOutlet weak var createAccountButton: NSButton!
	@IBOutlet weak var errorMessageLabel: NSTextField!
	@IBOutlet weak var actionButton: NSButton!
	@IBOutlet weak var noAccountTextField: NSTextField!
	
	var account: Account?
	var accountType: AccountType?
	
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsReaderAPI"))
	}
	
	override func windowDidLoad() {
		if let accountType = accountType {
			switch accountType {
			case .freshRSS:
				titleImageView.image = AppAsset.freshRSSImage
				titleLabel.stringValue = NSLocalizedString("Sign in to your FreshRSS account.", comment: "FreshRSS")
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a FreshRSS instance?", comment: "No FreshRSS")
				createAccountButton.title = NSLocalizedString("Find out more", comment: "No FreshRSS Button")
				apiURLTextField.placeholderString = NSLocalizedString("https://fresh.rss.net/api/greader.php", comment: "FreshRSS API Helper")
			case .inoreader:
				titleImageView.image = AppAsset.inoReaderImage
				titleLabel.stringValue = NSLocalizedString("Sign in to your InoReader account.", comment: "InoReader")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have an InoReader account?", comment: "No InoReader")
			case .bazQux:
				titleImageView.image = AppAsset.bazQuxImage
				titleLabel.stringValue = NSLocalizedString("Sign in to your BazQux account.", comment: "BazQux")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a BazQux account?", comment: "No BazQux")
			case .theOldReader:
				titleImageView.image = AppAsset.theOldReaderImage
				titleLabel.stringValue = NSLocalizedString("Sign in to your The Old Reader account.", comment: "The Old Reader")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("Don’t have a The Old Reader account?", comment: "No OldReader")
			default:
				break
			}
		}
		
		if let account = account, let credentials = try? account.retrieveCredentials(type: .readerBasic) {
			usernameTextField.stringValue = credentials.username
			apiURLTextField.stringValue = account.endpointURL?.absoluteString ?? ""
			actionButton.title = NSLocalizedString("Update", comment: "Update")
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
		}
		
		enableAutofill()
		usernameTextField.becomeFirstResponder()
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		self.hostWindow = hostWindow
		Task { @MainActor in
			await hostWindow.beginSheet(window!)
		}
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func action(_ sender: Any) {
		self.errorMessageLabel.stringValue = ""
		let apiURLString = apiURLTextField.stringValue

		guard !usernameTextField.stringValue.isEmpty && !passwordTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username, password & API URL are required.", comment: "Credentials Error")
			return
		}

		guard let accountType = accountType, !(accountType == .freshRSS && apiURLString.isEmpty) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username, password & API URL are required.", comment: "Credentials Error")
			return
		}

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: accountType, username: usernameTextField.stringValue, apiURL: apiURLString) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("There is already an account of this type with that username created.", comment: "Duplicate Error")
			return
		}

		let apiURL: URL
		switch accountType {
		case .freshRSS:
			guard let inputURL = URL(string: apiURLString) else {
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

		actionButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)

		let credentials = Credentials(type: .readerBasic, username: usernameTextField.stringValue, secret: passwordTextField.stringValue)

		Task { @MainActor in

			var validationDidThrow = false
			var validatedCredentials: Credentials?

			do {
				validatedCredentials = try await Account.validateCredentials(type: accountType, credentials: credentials, endpoint: apiURL)
			} catch {
				self.errorMessageLabel.stringValue = NSLocalizedString("Network error. Try again later.", comment: "Credentials Error")
				validationDidThrow = true
			}

			self.actionButton.isEnabled = true
			self.progressIndicator.isHidden = true
			self.progressIndicator.stopAnimation(self)

			if validationDidThrow {
				return
			}

			guard let validatedCredentials else {
				self.errorMessageLabel.stringValue = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
				return
			}

			if self.account == nil {
				self.account = AccountManager.shared.createAccount(type: self.accountType!)
			}

			do {
				self.account?.endpointURL = apiURL

				try self.account?.removeCredentials(type: .readerBasic)
				try self.account?.removeCredentials(type: .readerAPIKey)
				try self.account?.storeCredentials(credentials)
				try self.account?.storeCredentials(validatedCredentials)

				self.refreshAll()

				self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
			} catch {
				self.errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
			}
		}
	}
	
	private func refreshAll() {

		Task { @MainActor in
			do {
				try await self.account?.refreshAll()
			} catch {
				NSApplication.shared.presentError(error)
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {

		guard let createAccountURL = accountType.createAccountURL else {
			return
		}

		NSWorkspace.shared.open(createAccountURL)
	}
	
	// MARK: Autofill

	func enableAutofill() {

		usernameTextField.contentType = .username
		passwordTextField.contentType = .password
	}
}
