//
//  OAuthAccountAuthorizationOperation.swift
//  NetNewsWire
//
//  Created by Kiel Gillard on 8/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import AuthenticationServices

public protocol OAuthAccountAuthorizationOperationDelegate: class {
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account)
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error)
}

public final class OAuthAccountAuthorizationOperation: Operation, ASWebAuthenticationPresentationContextProviding {
	
	public weak var presentationAnchor: ASPresentationAnchor?
	public weak var delegate: OAuthAccountAuthorizationOperationDelegate?
	
	private let accountType: AccountType
	private let oauthClient: OAuthAuthorizationClient
	private var session: ASWebAuthenticationSession?
	
	public init(accountType: AccountType) {
		self.accountType = accountType
		self.oauthClient = Account.oauthAuthorizationClient(for: accountType)
	}
	
	override public func main() {
		assert(Thread.isMainThread)
		assert(presentationAnchor != nil, "\(self) outlived presentation anchor.")
		
		guard !isCancelled else {
			didFinish()
			return
		}
		
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
	
	override public func cancel() {
		session?.cancel()
		super.cancel()
	}
	
	private func didEndAuthentication(url: URL?, error: Error?) {
		guard !isCancelled else {
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
		guard !isCancelled else {
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
		assert(!isFinished, "Finished operation is attempting to finish again.")
		self.isExecutingOperation = false
		self.isFinishedOperation = true
	}
	
	private func didFinish(_ error: Error) {
		assert(Thread.isMainThread)
		assert(!isFinished, "Finished operation is attempting to finish again.")
		delegate?.oauthAccountAuthorizationOperation(self, didFailWith: error)
		didFinish()
	}
	
	override public func start() {
		isExecutingOperation = true
		DispatchQueue.main.async {
			self.main()
		}
	}
	
	override public var isExecuting: Bool {
		return isExecutingOperation
	}
	
	private var isExecutingOperation = false {
		willSet {
			willChangeValue(for: \.isExecuting)
		}
		didSet {
			didChangeValue(for: \.isExecuting)
		}
	}
	
	override public var isFinished: Bool {
		return isFinishedOperation
	}
	
	private var isFinishedOperation = false {
		willSet {
			willChangeValue(for: \.isFinished)
		}
		didSet {
			didChangeValue(for: \.isFinished)
		}
	}
}
