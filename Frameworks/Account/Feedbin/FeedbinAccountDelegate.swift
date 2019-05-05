//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
import RSCore
#endif
import RSWeb

final class FeedbinAccountDelegate: AccountDelegate {
	
	let supportsSubFolders = false
	let server: String? = "api.feedbin.com"
	
	private let caller: FeedbinAPICaller
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(transport: Transport) {
		caller = FeedbinAPICaller(transport: transport)
	}
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completionHandler completion: @escaping (Result<Bool, Error>) -> Void) {
		
		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			completion(result)
		}
		
	}
	
	func refreshAll(for account: Account, completionHandler completion: (() -> Void)? = nil) {
		refreshAll(account) { result in
			switch result {
			case .success():
				completion?()
			case .failure(let error):
				// TODO: We should do a better job of error handling here.
				// We need to prompt for credentials and provide user friendly
				// errors.
				#if os(macOS)
					NSApplication.shared.presentError(error)
				#else
					UIApplication.shared.presentError(error)
				#endif
			}
		}
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveBasicCredentials()
	}
	
}

// MARK: Private

private extension FeedbinAccountDelegate {
	
	func refreshAll(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		
		caller.retrieveTags { [weak self] result in
			switch result {
			case .success(let tags):
				self?.syncFolders(account, tags)
				completion(.success(()))
			case .failure(let error):
				self?.checkErrorOrNotModified(error, completion: completion)
			}
		}
		
	}
	
	func syncFolders(_ account: Account, _ tags: [FeedbinTag]) {
		
		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					account.deleteFolder(folder)
				}
			}
		}
		
		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders Feedbin has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				account.ensureFolder(with: tagName)
			}
		}
		
	}
	
	func checkErrorOrNotModified(_ error: Error, completion: @escaping (Result<Void, Error>) -> Void) {
		switch error {
		case TransportError.httpError(let status):
			if status == HTTPResponseCode.notModified {
				completion(.success(()))
			} else {
				completion(.failure(error))
			}
		default:
			completion(.failure(error))
		}

	}
	
}
