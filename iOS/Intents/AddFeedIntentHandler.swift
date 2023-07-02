//
//  AddFeedIntentHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Intents

public enum AddFeedIntentHandlerError: LocalizedError {
	
	case communicationFailure
	
	public var errorDescription: String? {
		switch self {
		case .communicationFailure:
			return NSLocalizedString("errordescription.localized.communication-failure", comment: "Unable to communicate with NetNewsWire.")
		}
	}
	
}

public class AddFeedIntentHandler: NSObject, AddFeedIntentHandling {

	override init() {
		super.init()
	}
	
	public func resolveUrl(for intent: AddFeedIntent, with completion: @escaping (AddFeedUrlResolutionResult) -> Void) {
		guard let url = intent.url else {
			completion(.unsupported(forReason: .required))
			return
		}
		completion(.success(with: url))
	}
	
	public func resolveTitle(for intent: AddFeedIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		guard let title = intent.title else {
			completion(INStringResolutionResult.notRequired())
			return
		}
		completion(.success(with: title))
	}
	
	public func provideAccountNameOptionsCollection(for intent: AddFeedIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(nil, AddFeedIntentHandlerError.communicationFailure)
			return
		}

		let accountNames = extensionContainers.accounts.map { $0.name }
		completion(INObjectCollection(items: accountNames as [NSString]), nil)
	}

	public func resolveAccountName(for intent: AddFeedIntent, with completion: @escaping (AddFeedAccountNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName else {
			completion(AddFeedAccountNameResolutionResult.notRequired())
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
	
	public func provideFolderNameOptions(for intent: AddFeedIntent, with completion: @escaping ([String]?, Error?) -> Void) {
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(nil, AddFeedIntentHandlerError.communicationFailure)
			return
		}

		guard let accountName = intent.accountName, let account = extensionContainers.findAccount(forName: accountName) else {
			completion([String](), nil)
			return
		}

		let folderNames = account.folders.map { $0.name }
		completion(folderNames, nil)
	}
	
	public func provideFolderNameOptionsCollection(for intent: AddFeedIntent, with completion: @escaping (INObjectCollection<NSString>?, Error?) -> Void) {
		guard let extensionContainers = ExtensionContainersFile.read() else {
			completion(nil, AddFeedIntentHandlerError.communicationFailure)
			return
		}

		guard let accountName = intent.accountName, let account = extensionContainers.findAccount(forName: accountName) else {
			completion(INObjectCollection(items: [NSString]()), nil)
			return
		}

		let folderNames = account.folders.map { $0.name }
		completion(INObjectCollection(items: folderNames as [NSString]), nil)
	}

	public func resolveFolderName(for intent: AddFeedIntent, with completion: @escaping (AddFeedFolderNameResolutionResult) -> Void) {
		guard let accountName = intent.accountName, let folderName = intent.folderName else {
			completion(AddFeedFolderNameResolutionResult.notRequired())
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
	
	public func handle(intent: AddFeedIntent, completion: @escaping (AddFeedIntentResponse) -> Void) {
		guard let url = intent.url, let extensionContainers = ExtensionContainersFile.read() else {
			completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
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
			completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
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
			completion(AddFeedIntentResponse(code: .failure, userActivity: nil))
			return
		}

		let request = ExtensionFeedAddRequest(name: intent.title, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)
		completion(AddFeedIntentResponse(code: .success, userActivity: nil))
	}
		
}
