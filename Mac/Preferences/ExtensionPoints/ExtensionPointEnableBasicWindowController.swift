//
//  ExtensionPointEnableBasicWindowController.swift
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
	
	private weak var hostWindow: NSWindow?

	private let callbackURL = URL(string: "vincodennw://")!
	private var oauth: OAuthSwift?

	var extensionPointType: ExtensionPoint.Type?

	convenience init() {
		self.init(windowNibName: NSNib.Name("ExtensionPointEnableBasic"))
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
		
		if let oauth1 = extensionPointType as? OAuth1SwiftProvider.Type {
			enableOauth1(oauth1)
		} else {
			ExtensionPointManager.shared.activateExtensionPoint(extensionPointType)
			hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
		}
		
	}

}

extension ExtensionPointEnableWindowController: OAuthSwiftURLHandlerType {
	
	public func handle(_ url: URL) {
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURL.scheme, completionHandler: { (url, error) in
			if let callbackedURL = url {
				OAuth1Swift.handle(url: callbackedURL)
			}
			
			guard let error = error else { return }

			self.oauth?.cancel()
			self.oauth = nil
			
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
		
		let oauth1 = provider.oauth1Swift
		self.oauth = oauth1
		oauth1.authorizeURLHandler = self
		
		oauth1.authorize(withCallbackURL: callbackURL) { [weak self] result in
			guard let self = self else { return }

			switch result {
			case .success(let tokenSuccess):
				
				//				let token = tokenSuccess.credential.oauthToken
				//				let secret = tokenSuccess.credential.oauthTokenSecret
				let screenName = tokenSuccess.parameters["screen_name"] as? String ?? ""
				print("******************* \(screenName)")
				self.hostWindow!.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)

			case .failure(let oauthSwiftError):
				NSApplication.shared.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
		
	}
	
}
