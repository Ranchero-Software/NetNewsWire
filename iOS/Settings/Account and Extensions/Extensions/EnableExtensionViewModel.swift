//
//  EnableExtensionViewModel.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 19/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation
import AuthenticationServices
import Account
import OAuthSwift
import Secrets
import RSCore


public final class EnableExtensionViewModel: NSObject, ObservableObject, OAuthSwiftURLHandlerType, ASWebAuthenticationPresentationContextProviding, Logging {
	
	@Published public var showExtensionError: (Error?, Bool) = (nil, false)
	private var extensionPointType: ExtensionPoint.Type?
	private var oauth: OAuthSwift?
	private var callbackURL: URL? = nil
	
	
	func configure(_ extensionPointType: ExtensionPoint.Type) {
		self.extensionPointType = extensionPointType
	}
	
	func enableExtension() async throws {
		guard let extensionPointType = extensionPointType else { return }
		if let oauth1 = extensionPointType as? OAuth1SwiftProvider.Type {
			try await enableOAuth1(oauth1)
		} else if let oauth2 = extensionPointType as? OAuth2SwiftProvider.Type {
			try await enableOAuth2(oauth2)
		} else {
			try await activateExtensionPoint(extensionPointType)
		}
	}
	
	private func activateExtensionPoint(_ point: ExtensionPoint.Type) async throws {
		return try await withCheckedThrowingContinuation { continuation in
			ExtensionPointManager.shared.activateExtensionPoint(point) { result in
				switch result {
				case .success(_):
					continuation.resume()
					return
				case .failure(let failure):
					continuation.resume(throwing: failure)
					return
				}
			}
		}
	}
	
	// MARK: Enable OAuth
	private func enableOAuth1(_ provider: OAuth1SwiftProvider.Type) async throws {
		callbackURL = provider.callbackURL
		
		let oauth1 = provider.oauth1Swift
		self.oauth = oauth1
		oauth1.authorizeURLHandler = self
		
		return try await withCheckedThrowingContinuation { continuation in
			oauth1.authorize(withCallbackURL: callbackURL!) { [weak self] result in
				
				guard let self = self, let extensionPointType = self.extensionPointType else { return }
				
				switch result {
				case .success(let tokenSuccess):
					ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { result in
						switch result {
						case .success(_):
							continuation.resume()
							return
						case .failure(let failure):
							continuation.resume(throwing: failure)
							return
						}
					}
				case .failure(let error):
					continuation.resume(throwing: error)
					return
				}
				
				self.oauth?.cancel()
				self.oauth = nil
			}
			continuation.resume()
		}
		
	}
	
	private func enableOAuth2(_ provider: OAuth2SwiftProvider.Type) async throws {
		
		callbackURL = provider.callbackURL

		let oauth2 = provider.oauth2Swift
		self.oauth = oauth2
		oauth2.authorizeURLHandler = self
		
		let oauth2Vars = provider.oauth2Vars
		
		return try await withCheckedThrowingContinuation { continuation in
			oauth2.authorize(withCallbackURL: callbackURL!, scope: oauth2Vars.scope, state: oauth2Vars.state, parameters: oauth2Vars.params) { [weak self] result in
				guard let self = self, let extensionPointType = self.extensionPointType else { return }
				
				switch result {
				case .success(let tokenSuccess):
					ExtensionPointManager.shared.activateExtensionPoint(extensionPointType, tokenSuccess: tokenSuccess) { [weak self] result in
						switch result {
						case .success(_):
							self?.logger.debug("Enabled extension successfully.")
						case .failure(let failure):
							continuation.resume(throwing: failure)
							return
						}
						
					}
				case .failure(let oauthSwiftError):
					continuation.resume(throwing: oauthSwiftError)
					return
				}
				
				self.oauth?.cancel()
				self.oauth = nil
			}
			continuation.resume()
		}
	}
	
	public func handle(_ url: URL) {
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURL!.scheme, completionHandler: { (url, error) in
			if let callbackedURL = url {
				OAuth1Swift.handle(url: callbackedURL)
			}
			
			guard let error = error else { return }

			self.oauth?.cancel()
			self.oauth = nil

			DispatchQueue.main.async {
				//self.dismiss(animated: true, completion: nil)
				//self.delegate?.dismiss()
			}

			if case ASWebAuthenticationSessionError.canceledLogin = error {
				print("Login cancelled.")
			} else {
				self.showExtensionError = (error, true)
			}
		})
		
		session.presentationContextProvider = self
		if !session.start() {
			print("Session failed to start!!!")
		}
	}
	
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		return rootViewController!.view.window!
	}
	
	public var rootViewController: UIViewController? {
		var currentKeyWindow: UIWindow? {
			UIApplication.shared.connectedScenes
				.filter { $0.activationState == .foregroundActive }
				.map { $0 as? UIWindowScene }
				.compactMap { $0 }
				.first?.windows
				.filter { $0.isKeyWindow }
				.first
		}
		
		var rootViewController: UIViewController? {
			currentKeyWindow?.rootViewController
		}
		
		return rootViewController
	}
	
}
