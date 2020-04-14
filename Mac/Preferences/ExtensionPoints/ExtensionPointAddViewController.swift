//
//  ExtensionPointAddViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import AuthenticationServices
import Secrets
import OAuthSwift
import FeedProvider

class ExtensionPointAddViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	
	private var availableExtensionPointTypes = [ExtensionPointType]()
	private var extensionPointAddWindowController: NSWindowController?

	private let callbackURL = URL(string: "vincodennw://")!
	private var oauth: OAuthSwift?

	init() {
		super.init(nibName: "ExtensionPointAdd", bundle: nil)
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
        super.viewDidLoad()
		tableView.dataSource = self
		tableView.delegate = self
		availableExtensionPointTypes = ExtensionPointManager.shared.availableExtensionPointTypes
    }
    
}

// MARK: - NSTableViewDataSource

extension ExtensionPointAddViewController: NSTableViewDataSource {
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return availableExtensionPointTypes.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return nil
	}
}

// MARK: - NSTableViewDelegate

extension ExtensionPointAddViewController: NSTableViewDelegate {
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? ExtensionPointAddTableCellView {
			let extensionPointType = availableExtensionPointTypes[row]
			cell.titleLabel?.stringValue = extensionPointType.title
			cell.imageView?.image = extensionPointType.templateImage
			return cell
		}
		return nil
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		guard selectedRow != -1 else {
			return
		}

		let extensionPointType = availableExtensionPointTypes[selectedRow]
		switch extensionPointType {
		case .marsEdit, .microblog:
			
			let windowController = ExtensionPointEnableBasicWindowController()
			windowController.extensionPointType = extensionPointType
			windowController.runSheetOnWindow(self.view.window!)
			extensionPointAddWindowController = windowController
			
		case .twitter:

			let oauth = OAuth1Swift(
				consumerKey: Secrets.twitterConsumerKey,
				consumerSecret: Secrets.twitterConsumerSecret,
				requestTokenUrl: "https://api.twitter.com/oauth/request_token",
				authorizeUrl:    "https://api.twitter.com/oauth/authorize",
				accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
			)
			
			self.oauth = oauth
			oauth.authorizeURLHandler = self
			
			oauth.authorize(withCallbackURL: callbackURL) { result in
				switch result {
				case .success(let tokenSuccess):
					//				let token = tokenSuccess.credential.oauthToken
					//				let secret = tokenSuccess.credential.oauthTokenSecret
					let screenName = tokenSuccess.parameters["screen_name"] as? String ?? ""
					
					print("******************* \(screenName)")
					
				case .failure(let oauthSwiftError):
					NSApplication.shared.presentError(oauthSwiftError)
				}
				
				self.oauth?.cancel()
				self.oauth = nil
			}
			
		}
		
		tableView.selectRowIndexes([], byExtendingSelection: false)
		
	}
	
}

extension ExtensionPointAddViewController: OAuthSwiftURLHandlerType {
	
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
extension ExtensionPointAddViewController: ASWebAuthenticationPresentationContextProviding {
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return view.window!
	}
	
}
