//
//  OAuthAccountAuthorizationOperation.swift
//  NetNewsWire
//
//  Created by Kiel Gillard on 8/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import AuthenticationServices
import RSCore

public protocol OAuthAccountAuthorizationOperationDelegate: class {
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account)
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error)
}

@objc public final class OAuthAccountAuthorizationOperation: NSObject, MainThreadOperation, ASWebAuthenticationPresentationContextProviding {

	public var isCanceled: Bool = false {
		didSet {
			if isCanceled {
				cancel()
			}
		}
	}
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	public weak var presentationAnchor: ASPresentationAnchor?
	public weak var delegate: OAuthAccountAuthorizationOperationDelegate?
	
	private let accountType: AccountType
	private let oauthClient: OAuthAuthorizationClient
	private var session: ASWebAuthenticationSession?
	
	public init(accountType: AccountType) {
		self.accountType = accountType
		self.oauthClient = Account.oauthAuthorizationClient(for: accountType)
	}
	
	public func run() {
		assert(presentationAnchor != nil, "\(self) outlived presentation anchor.")
		
		let request = Account.oauthAuthorizationCodeGrantRequest(for: accountType)
		
		guard let url = request.url else {
			return DispatchQueue.main.async {
				self.didEndAuthentication(url: nil, error: URLError(.badURL))
			}
		}
		
		guard let redirectUri = URL(string: oauthClient.redirectUri), let scheme = redirectUri.scheme else {
			assertionFailure("Could not get callback URL scheme from \(oauthClient.redirectUri)")
			return DispatchQueue.main.async {
				self.didEndAuthentication(url: nil, error: URLError(.badURL))
			}
		}
		
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { url, error in
			DispatchQueue.main.async { [weak self] in
				self?.didEndAuthentication(url: url, error: error)
			}
		}
		self.session = session
		session.presentationContextProvider = self
		
		session.start()
	}
	
	public func cancel() {
		session?.cancel()
	}
	
	private func didEndAuthentication(url: URL?, error: Error?) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		do {
			guard let url = url else {
				if let error = error {
					throw error
				}
				throw URLError(.badURL)
			}
			
			let response = try OAuthAuthorizationResponse(url: url, client: oauthClient)
			
			Account.requestOAuthAccessToken(with: response, client: oauthClient, accountType: accountType, completion: didEndRequestingAccessToken(_:))
			
		} catch is ASWebAuthenticationSessionError {
			didFinish() // Primarily, cancellation.
			
		} catch {
			didFinish(error)
		}
	}
	
	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		guard let anchor = presentationAnchor else {
			fatalError("\(self) has outlived presentation anchor.")
		}
		return anchor
	}
	
	private func didEndRequestingAccessToken(_ result: Result<OAuthAuthorizationGrant, Error>) {
		guard !isCanceled else {
			didFinish()
			return
		}
		
		switch result {
		case .success(let tokenResponse):
			saveAccount(for: tokenResponse)
		case .failure(let error):
			didFinish(error)
		}
	}
	
	private func saveAccount(for grant: OAuthAuthorizationGrant) {
		// TODO: Find an already existing account for this username?
		let account = AccountManager.shared.createAccount(type: .feedly)
		do {
			
			// Store the refresh token first because it sends this token to the account delegate.
			if let token = grant.refreshToken {
				try account.storeCredentials(token)
			}
			
			// Now store the access token because we want the account delegate to use it.
			try account.storeCredentials(grant.accessToken)
			
			delegate?.oauthAccountAuthorizationOperation(self, didCreate: account)
						
			didFinish()
		} catch {
			didFinish(error)
		}
	}
	
	// MARK: Managing Operation State
	
	private func didFinish() {
		assert(Thread.isMainThread)
		operationDelegate?.operationDidComplete(self)
	}
	
	private func didFinish(_ error: Error) {
		assert(Thread.isMainThread)
		delegate?.oauthAccountAuthorizationOperation(self, didFailWith: error)
		didFinish()
	}
}
