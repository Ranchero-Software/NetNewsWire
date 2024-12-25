//
//  AddWebFeedIntentHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Intents

public enum AddWebFeedIntentHandlerError: LocalizedError {
	
	case communicationFailure
	
	public var errorDescription: String? {
		switch self {
		case .communicationFailure:
			return NSLocalizedString("Unable to communicate with NetNewsWire.", comment: "Communication failure")
		}
	}
	
}

public class AddWebFeedIntentHandler: NSObject, AddWebFeedIntentHandling {

	override init() {
		super.init()
	}
	
	public func resolveUrl(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedUrlResolutionResult) -> Void) {
		guard let url = intent.url else {
			completion(.unsupported(forReason: .required))
			return
		}
		completion(.success(with: url))
	}
	
	public func provideAccountNameOptions(for intent: AddWebFeedIntent, with completion: @escaping ([String]?, Error?) -> Void) {
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(nil, AddWebFeedIntentHandlerError.communicationFailure)
			return
		}

		let accountNames = extensionContainers.accounts.map { $0.name }
		completion(accountNames, nil)
	}
	
	public func resolveAccountName(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedAccountNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName else {
			completion(AddWebFeedAccountNameResolutionResult.notRequired())
			return
		}

		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(.unsupported(forReason: .communication))
			return
		}

		if extensionContainers.findAccount(forName: accountName) == nil {
			completion(.unsupported(forReason: .invalid))
		} else {
			completion(.success(with: accountName))
		}
	}
	
	public func provideFolderNameOptions(for intent: AddWebFeedIntent, with completion: @escaping ([String]?, Error?) -> Void) {
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(nil, AddWebFeedIntentHandlerError.communicationFailure)
			return
		}

		guard let accountName = intent.accountName, let account = extensionContainers.findAccount(forName: accountName) else {
			completion([String](), nil)
			return
		}

		let folderNames = account.folders.map { $0.name }
		completion(folderNames, nil)
	}
	
	public func resolveFolderName(for intent: AddWebFeedIntent, with completion: @escaping (AddWebFeedFolderNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName, let folderName = intent.folderName else {
			completion(AddWebFeedFolderNameResolutionResult.notRequired())
			return
		}
		
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(.unsupported(forReason: .communication))
			return
		}

		guard let account = extensionContainers.findAccount(forName: accountName) else {
			completion(.unsupported(forReason: .invalid))
			return
		}
		
		if account.findFolder(forName: folderName) == nil {
			completion(.unsupported(forReason: .invalid))
		} else {
			completion(.success(with: folderName))
		}
		return

	}
	
	public func handle(intent: AddWebFeedIntent, completion: @escaping (AddWebFeedIntentResponse) -> Void) {
		guard let url = intent.url, let extensionContainers = ExtensionContainersFile.read() else {
			completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}
		
		let account: ExtensionAccount? = {
			if let accountName = intent.accountName {
				return extensionContainers.findAccount(forName: accountName)
			} else {
				return extensionContainers.accounts.first
			}
		}()

		guard let validAccount = account else {
			completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}

		let container: ExtensionContainer? = {
			if let folderName = intent.folderName {
				return validAccount.findFolder(forName: folderName)
			} else {
				return validAccount
			}
		}()

		guard let validContainer = container, let containerID = validContainer.containerID else {
			completion(AddWebFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}

		let request = ExtensionFeedAddRequest(name: nil, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)
		completion(AddWebFeedIntentResponse(code: .success, userActivity: nil))
	}
		
}
