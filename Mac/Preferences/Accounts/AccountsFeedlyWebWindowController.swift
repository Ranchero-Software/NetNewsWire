//
//  AccountsFeedlyWebWindowController.swift
//  NetNewsWire
//
//  Created by Kiel Gillard on 30/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Cocoa
import Account
import WebKit

class AccountsFeedlyWebWindowController: NSWindowController, WKNavigationDelegate {
	
	@IBOutlet private weak var webView: WKWebView!
	
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsFeedlyWeb"))
	}

	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: handler)
		beginAuthorization()
	}
	
	// MARK: Requesting an Access Token
	
	private let client = OAuthAuthorizationClient.feedlySandboxClient
	
	private func beginAuthorization() {
		let request = Account.oauthAuthorizationCodeGrantRequest(for: .feedly, client: client)
		webView.load(request)
	}
	
	private func requestAccessToken(for response: OAuthAuthorizationResponse) {
		Account.requestOAuthAccessToken(with: response, client: client, accountType: .feedly) { [weak self] result in
			switch result {
			case .success(let tokenResponse):
				self?.saveAccount(for: tokenResponse)
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		do {
			guard let url = navigationAction.request.url else { return }
			
			let response = try OAuthAuthorizationResponse(url: url, client: client)
			
			requestAccessToken(for: response)
			
			// No point the web view trying to load this.
			return decisionHandler(.cancel)
			
		} catch let error as OAuthAuthorizationErrorResponse {
			NSApplication.shared.presentError(error)
			
		} catch {
			NSApplication.shared.presentError(error)
		}
		
		decisionHandler(.allow)
	}
	
	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		print(error)
	}
	
	private func saveAccount(for grant: OAuthAuthorizationGrant) {
		// TODO: Find an already existing account for this username?
		let account = AccountManager.shared.createAccount(type: .feedly)
		do {
			try account.storeCredentials(grant.accessToken)
			
			if let token = grant.refreshToken {
				try account.storeCredentials(token)
			}
			
			self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
		} catch {
			NSApplication.shared.presentError(error)
		}
	}
}

private extension OAuthAuthorizationClient {
	
	/// Models public sandbox API values found at:
	/// https://groups.google.com/forum/#!topic/feedly-cloud/WwQWMgDmOuw
	static var feedlySandboxClient: OAuthAuthorizationClient {
		return OAuthAuthorizationClient(id: "sandbox",
										redirectUri: "http://localhost",
										state: nil,
										secret: "ReVGXA6WekanCxbf")
	}
	
	/// Models private NetNewsWire client secrets.
	/// https://developer.feedly.com/v3/auth/#authenticating-a-user-and-obtaining-an-auth-code
	static var netNewsWireClient: OAuthAuthorizationClient {
		fatalError("This app is not registered as a client with Feedly. Follow the URL in the code comments for this property.")
	}
}
