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
import RSCore
import Secrets
import ReaderAPI

@MainActor class AccountsReaderAPIWindowController: NSWindowController, Logging {

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
				titleImageView.image = AppAssets.accountFreshRSS
				titleLabel.stringValue = NSLocalizedString("label.text.sign-in-freshrss", comment: "Sign in to your FreshRSS account.")
				noAccountTextField.stringValue = NSLocalizedString("label.text.no-fresh-rss", comment: "Don’t have a FreshRSS instance?")
				createAccountButton.title = NSLocalizedString("label.text.find-out-more", comment: "Find out more")
				apiURLTextField.placeholderString = "fresh.rss.net/api/greader.php" // not localized.
			case .inoreader:
				titleImageView.image = AppAssets.accountInoreader
				titleLabel.stringValue = NSLocalizedString("label.text.sign-in-inoreader", comment: "Sign in to your InoReader account.")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("label.text.no-inoreader", comment: "Don’t have an InoReader account?")
			case .bazQux:
				titleImageView.image = AppAssets.accountBazQux
				titleLabel.stringValue = NSLocalizedString("label.text.sign-in-bazqux", comment: "Sign in to your BazQux account.")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("label.text.no-bazqux", comment: "Don’t have a BazQux account?")
			case .theOldReader:
				titleImageView.image = AppAssets.accountTheOldReader
				titleLabel.stringValue = NSLocalizedString("label.text.sign-in-old-reader", comment: "Sign in to your The Old Reader account.")
				gridView.row(at: 2).isHidden = true
				noAccountTextField.stringValue = NSLocalizedString("label.text.no-old-reader", comment: "Don’t have a The Old Reader account?")
			default:
				break
			}
		}
		
		if let account = account, let credentials = try? account.retrieveCredentials(type: .readerBasic) {
			usernameTextField.stringValue = credentials.username
			apiURLTextField.stringValue = account.endpointURL?.absoluteString ?? ""
			actionButton.title = NSLocalizedString("button.title.update", comment: "Update")
		} else {
			actionButton.title = NSLocalizedString("button.title.create", comment: "Create")
		}
		
		enableAutofill()
		usernameTextField.becomeFirstResponder()
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: completion)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func action(_ sender: Any) {
		self.errorMessageLabel.stringValue = ""
		
		guard !usernameTextField.stringValue.isEmpty && !passwordTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.userNameAndPasswordRequired.localizedDescription
			return
		}
		
		guard let accountType = accountType, !(accountType == .freshRSS && apiURLTextField.stringValue.isEmpty) else {
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.userNamePasswordAndURLRequired.localizedDescription
			return
		}
		
		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: accountType, username: usernameTextField.stringValue) else {
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.duplicateAccount.localizedDescription
			return
		}
		
		let apiURL: URL
		switch accountType {
		case .freshRSS:
			guard let inputURL = URL(string: apiURLTextField.stringValue) else {
				self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.invalidURL.localizedDescription
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
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.unrecognizedAccount.localizedDescription
			return
		}
		
		actionButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)
		
		let credentials = Credentials(type: .readerBasic, username: usernameTextField.stringValue, secret: passwordTextField.stringValue)

		Task { @MainActor in

			do {
				let validatedCredentials = try await Account.validateCredentials(type: accountType, credentials: credentials, endpoint: apiURL)
				if let validatedCredentials {
					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: self.accountType!)
					}

					do {
						self.account?.endpointURL = apiURL

						try self.account?.removeCredentials(type: .readerBasic)
						try self.account?.removeCredentials(type: .readerAPIKey)
						try self.account?.storeCredentials(credentials)
						try self.account?.storeCredentials(validatedCredentials)

						self.account?.refreshAll() { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
						}

						self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
					} catch {
						self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.keychainError.localizedDescription
						self.logger.error("Keychain error while storing credentials: \(error.localizedDescription, privacy: .public)")
					}
				}
				else {
					self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.invalidUsernameOrPassword.localizedDescription
				}
			} catch {
				self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.networkError.localizedDescription
			}

			self.actionButton.isEnabled = true
			self.progressIndicator.isHidden = true
			self.progressIndicator.stopAnimation(self)
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
