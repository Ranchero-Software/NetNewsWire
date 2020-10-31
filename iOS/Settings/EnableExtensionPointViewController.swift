//
//  EnableExtensionPointViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/16/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import AuthenticationServices
import Account
import OAuthSwift
import Secrets

class EnableExtensionPointViewController: UITableViewController {

	@IBOutlet weak var extensionDescription: UILabel!
	
	private var callbackURL: URL? = nil
	private var oauth: OAuthSwift?

	weak var delegate: AddExtensionPointDismissDelegate?
	var extensionPointType: ExtensionPoint.Type?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = extensionPointType?.title
		extensionDescription.attributedText = extensionPointType?.description
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func enable(_ sender: Any) {
		guard let extensionPointType = extensionPointType else { return }
		
		if let oauth1 = extensionPointType as? OAuth1SwiftProvider.Type {
			enableOauth1(oauth1)
		} else if let oauth2 = extensionPointType as? OAuth2SwiftProvider.Type {
			enableOauth2(oauth2)
		} else {
			ExtensionPointManager.shared.activateExtensionPoint(extensionPointType) { result in
				if case .failure(let error) = result {
					self.presentError(error)
				}
				self.dismiss(animated: true, completion: nil)
				self.delegate?.dismiss()
			}
		}
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = extensionPointType?.image
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}
	
}

extension EnableExtensionPointViewController: OAuthSwiftURLHandlerType {
	
	public func handle(_ url: URL) {
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURL!.scheme, completionHandler: { (url, error) in
			if let callbackedURL = url {
				OAuth1Swift.handle(url: callbackedURL)
			}
			
			guard let error = error else { return }

			self.oauth?.cancel()
			self.oauth = nil

			DispatchQueue.main.async {
				self.dismiss(animated: true, completion: nil)
				self.delegate?.dismiss()
			}

			if case ASWebAuthenticationSessionError.canceledLogin = error {
				print("Login cancelled.")
			} else {
				self.presentError(error)
			}
		})
		
		session.presentationContextProvider = self
		if !session.start() {
			print("Session failed to start!!!")
		}
		
	}
}

extension EnableExtensionPointViewController: ASWebAuthenticationPresentationContextProviding {
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return view.window!
	}
	
}

private extension EnableExtensionPointViewController {
	
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
					self.dismiss(animated: true, completion: nil)
					self.delegate?.dismiss()
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
					self.dismiss(animated: true, completion: nil)
					self.delegate?.dismiss()
				}
			case .failure(let oauthSwiftError):
				self.presentError(oauthSwiftError)
			}
			
			self.oauth?.cancel()
			self.oauth = nil
		}
	}
	

}
