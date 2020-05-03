//
//  ExtensionPointEnableWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Cocoa
import AuthenticationServices
import OAuthSwift
import Secrets

class ExtensionPointEnableWindowController: NSWindowController {

	@IBOutlet weak var imageView: NSImageView!
	@IBOutlet weak var titleLabel: NSTextField!
	@IBOutlet weak var descriptionLabel: NSTextField!
	@IBOutlet weak var enableButton: NSButton!
	
	private weak var hostWindow: NSWindow?

	private var callbackURL: URL? = nil
	private var oauth: OAuthSwift?

	var extensionPointType: ExtensionPoint.Type?

	convenience init() {
		self.init(windowNibName: NSNib.Name("ExtensionPointEnable"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		guard let extensionPointType = extensionPointType else { return }
		
		imageView.image = extensionPointType.templateImage
		titleLabel.stringValue = extensionPointType.title
		descriptionLabel.attributedStringValue = extensionPointType.description
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func enable(_ sender: Any) {
		guard let extensionPointType = extensionPointType else { return }
		
		enableButton.isEnabled = false
		
		if let oauth1 = extensionPointType as? OAuth1SwiftProvider.Type {
			enableOauth1(oauth1)
		} else if let oauth2 = extensionPointType as? OAuth2SwiftProvider.Type {
			enableOauth2(oauth2)
		} else {
			ExtensionPointManager.shared.activateExtensionPoint(extensionPointType) { result in
				if case .failure(let error) = result {
					self.presentError(error)
				}
				self.hostWindow!.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
			}
		}
		
	}

}

extension ExtensionPointEnableWindowController: OAuthSwiftURLHandlerType {
	
	public func handle(_ url: URL) {
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURL!.scheme, completionHandler: { (url, error) in
			if let callbackedURL = url {
				OAuth1Swift.handle(url: callbackedURL)
			}
			
			guard let error = error else { return }

			self.oauth?.cancel()
			self.oauth = nil

			DispatchQueue.main.async {
				self.hostWindow!.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
			}

			if case ASWebAuthenticationSessionError.canceledLogin = error {
				print("Login cancelled.")
			} else {
				NSApplication.shared.presentError(error)
			}
		})
		
		session.presentationContextProvider = self
		if !session.start() {
			print("Session failed to start!!!")
		}
		
	}
}

extension ExtensionPointEnableWindowController: ASWebAuthenticationPresentationContextProviding {
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return hostWindow!
	}
	
}

private extension ExtensionPointEnableWindowController {
	
	func enableOauth1(_ provider: OAuth1SwiftProvider.Type) {
		callbackURL = provider.callbackURL

		let oauth1 = provider.oauth1Swift
		self.oauth = oauth1
		oauth1.authorizeURLHandler = self
		
		oauth1.authorize(withCallbackURL: callbackURL!) { [weak self] result in
			guard let self = self, let extensionPointType = self.extensionPointType else { return }

			switch result {
			case .success(let tokenSuccess):
				ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { result in
					if case .failure(let error) = result {
						self.presentError(error)
					}
					self.hostWindow!.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
				}
			case .failure(let oauthSwiftError):
				self.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
		
	}
	
	func enableOauth2(_ provider: OAuth2SwiftProvider.Type) {
		callbackURL = provider.callbackURL

		let oauth2 = provider.oauth2Swift
		self.oauth = oauth2
		oauth2.authorizeURLHandler = self
		
		let oauth2Vars = provider.oauth2Vars
		
		oauth2.authorize(withCallbackURL: callbackURL!, scope: oauth2Vars.scope, state: oauth2Vars.state, parameters: oauth2Vars.params) { [weak self] result in
			guard let self = self, let extensionPointType = self.extensionPointType else { return }

			switch result {
			case .success(let tokenSuccess):
				ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { result in
					if case .failure(let error) = result {
						self.presentError(error)
					}
					self.hostWindow!.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
				}
			case .failure(let oauthSwiftError):
				self.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
		
	}
	
}
