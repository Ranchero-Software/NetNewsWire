//
//  OAuthAccountAuthorizationOperation.swift
//  NetNewsWire
//
//  Created by Kiel Gillard on 8/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
@preconcurrency import AuthenticationServices
import os
import ActivityLog
import RSCore

@MainActor public protocol OAuthAccountAuthorizationOperationDelegate: AnyObject {
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account)
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error)
}

public enum OAuthAccountAuthorizationOperationError: LocalizedError, Sendable {
	case duplicateAccount
	case stateMismatch

	public var errorDescription: String? {
		switch self {
		case .duplicateAccount:
			return NSLocalizedString("There is already a Feedly account with that username created.", comment: "Duplicate Error")
		case .stateMismatch:
			return NSLocalizedString("The authorization response didn’t match the authorization request.", comment: "OAuth - error description - state parameter in callback didn’t match the request.")
		}
	}
}

/// Documentation does not say on why `ASWebAuthenticationSession.start` or `canStart` might return false.
/// Perhaps it has something to do with an inter-process communication failure?
/// No browsers installed? No browsers that support web authentication?
struct UnableToStartASWebAuthenticationSessionError: LocalizedError, Sendable {
	let errorDescription: String? = NSLocalizedString(
		"Unable to start a web authentication session with the default web browser.",
		comment: "OAuth - error description - unable to authorize because ASWebAuthenticationSession did not start.")
	let recoverySuggestion: String? = NSLocalizedString(
		"Check your default web browser in System Preferences or change it to Safari and try again.",
		comment: "OAuth - recovery suggestion - ensure browser selected supports web authentication.")
}

@objc nonisolated final class PresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
	nonisolated(unsafe) var presentationAnchor: ASPresentationAnchor?

	// MARK: - ASWebAuthenticationPresentationContextProviding

	public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
		guard let presentationAnchor else {
			preconditionFailure("presentationAnchor is required")
		}
		return presentationAnchor
	}
}

public final class OAuthAccountAuthorizationOperation: MainThreadOperation, @unchecked Sendable {
	public var presentationAnchor: ASPresentationAnchor? {
		get {
			anchorProvider.presentationAnchor
		}
		set {
			anchorProvider.presentationAnchor = newValue
		}
	}

	public weak var delegate: OAuthAccountAuthorizationOperationDelegate?

	private let accountType: AccountType
	private let oauthClient: OAuthAuthorizationClient
	nonisolated(unsafe) private let anchorProvider = PresentationAnchorProvider()
	nonisolated(unsafe) private var session: ASWebAuthenticationSession?
	private var error: Error?
	private var activityID: Int?
	private var userCancelledAuthentication = false

	// Round-tripped via the OAuth state parameter to verify the callback answers our request.
	private let state = UUID().uuidString
	nonisolated private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "OAuthAccountAuthorizationOperation")

	public init(accountType: AccountType) {
		self.accountType = accountType
		self.oauthClient = Account.oauthAuthorizationClient(for: accountType)
		super.init(name: "OAuthAccountAuthorizationOperation")
	}

	public override func run() {
		Self.logger.debug("OAuthAccountAuthorizationOperation: run")
		assert(presentationAnchor != nil, "\(self) outlived presentation anchor.")

		let id = ActivityLog.shared.createActivity(owner: .app, kind: .validateCredentials, detail: "Authorizing \(accountType.displayName)")
		ActivityLog.shared.didStart(id: id)
		activityID = id

		let request = Account.oauthAuthorizationCodeGrantRequest(for: accountType, state: state)

		guard let url = request.url else {
			didEndAuthentication(url: nil, error: URLError(.badURL))
			return
		}

		guard let redirectURI = URL(string: oauthClient.redirectURI), let scheme = redirectURI.scheme else {
			assertionFailure("Could not get callback URL scheme from \(oauthClient.redirectURI)")
			didEndAuthentication(url: nil, error: URLError(.badURL))
			return
		}

		Task.detached {
			self.createAndRunSession(url, scheme)
		}
	}

	override public func noteDidComplete() {
		Self.logger.debug("OAuthAccountAuthorizationOperation: noteDidComplete")

		if let activityID {
			if let error {
				ActivityLog.shared.didFail(id: activityID, error: error)
			} else if isCanceled || userCancelledAuthentication {
				ActivityLog.shared.didFail(id: activityID, error: CocoaError(.userCancelled))
			} else {
				ActivityLog.shared.didComplete(id: activityID)
			}
			self.activityID = nil
		}

		if isCanceled {
			Self.logger.debug("OAuthAccountAuthorizationOperation: noteDidComplete — canceled")
			session?.cancel()
		}
		if let error {
			Self.logger.error("OAuthAccountAuthorizationOperation: noteDidComplete — error: \(error.localizedDescription)")
			delegate?.oauthAccountAuthorizationOperation(self, didFailWith: error)
		}
	}
}

private extension OAuthAccountAuthorizationOperation {
	nonisolated func createAndRunSession(_ url: URL, _ scheme: String) {
		// Ideally this would also be on @MainActor — but there is an odd, unexplainable concurrency crash,
		// first observeed on macOS 26, when we do that.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4937>
		// This workaround — a nonisolated func that runs @MainActor tasks — avoids the crash.
		let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { url, error in
			Task { @MainActor in
				Self.logger.debug("OAuthAccountAuthorizationOperation: ASWebAuthenticationSession callback called")
				self.didEndAuthentication(url: url, error: error)
			}
		}

		session.presentationContextProvider = anchorProvider

		// Assign before starting so cancellation can always reach the session.
		self.session = session

		guard session.start() else {
			self.session = nil
			Task { @MainActor in
				Self.logger.error("OAuthAccountAuthorizationOperation: run — could not start session")
				error = UnableToStartASWebAuthenticationSessionError()
				didComplete()
			}
			return
		}
	}

	func didEndAuthentication(url: URL?, error: Error?) {
		if let error {
			Self.logger.error("OAuthAccountAuthorizationOperation: didEndAuthentication url: \(url?.absoluteString ?? "") error: \(error.localizedDescription)")
		} else {
			Self.logger.debug("OAuthAccountAuthorizationOperation: didEndAuthentication url: \(url?.absoluteString ?? "")")
		}

		guard !isCanceled else {
			didComplete()
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

			guard response.state == state else {
				throw OAuthAccountAuthorizationOperationError.stateMismatch
			}

			Task { @MainActor in
				do {
					let grant = try await Account.requestOAuthAccessToken(with: response, client: oauthClient, accountType: accountType)
					self.didEndRequestingAccessToken(.success(grant))
				} catch {
					self.didEndRequestingAccessToken(.failure(error))
				}
			}

		} catch let sessionError as ASWebAuthenticationSessionError {
			if sessionError.code == .canceledLogin {
				userCancelledAuthentication = true
			} else {
				self.error = sessionError
			}
			didComplete()

		} catch {
			self.error = error
			didComplete()
		}
	}

	func didEndRequestingAccessToken(_ result: Result<OAuthAuthorizationGrant, Error>) {
		guard !isCanceled else {
			didComplete()
			return
		}

		switch result {
		case .success(let tokenResponse):
			Self.logger.debug("OAuthAccountAuthorizationOperation: didEndRequestingAccessToken — success")
			saveAccount(for: tokenResponse)
		case .failure(let error):
			Self.logger.error("OAuthAccountAuthorizationOperation: didEndRequestingAccessToken — failure: \(error.localizedDescription)")
			self.error = error
			didComplete()
		}
	}

	func saveAccount(for grant: OAuthAuthorizationGrant) {
		Self.logger.debug("OAuthAccountAuthorizationOperation: saveAccount")
		guard !AccountManager.shared.duplicateServiceAccount(type: .feedly, username: grant.accessToken.username) else {
			self.error = OAuthAccountAuthorizationOperationError.duplicateAccount
			didComplete()
			return
		}

		let account = AccountManager.shared.createAccount(type: .feedly)
		do {

			// Store the refresh token first because it sends this token to the account delegate.
			if let token = grant.refreshToken {
				try account.storeCredentials(token)
			}

			// Now store the access token because we want the account delegate to use it.
			try account.storeCredentials(grant.accessToken)

			delegate?.oauthAccountAuthorizationOperation(self, didCreate: account)
		} catch {
			// Don’t leave behind an account with no credentials.
			AccountManager.shared.deleteAccount(account)
			self.error = error
		}

		didComplete()
	}
}
