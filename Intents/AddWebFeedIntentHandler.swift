//
//  AddWebFeedIntentHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Intents

public enum AddWebFeedIntentHandlerError: LocalizedError, Sendable {
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

	public func resolveUrl(for intent: AddWebFeedIntent) async -> AddWebFeedUrlResolutionResult {
		guard let url = intent.url else {
			return .unsupported(forReason: .required)
		}
		return .success(with: url)
	}

	public func provideAccountNameOptions(for intent: AddWebFeedIntent) async throws -> [String] {
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			throw AddWebFeedIntentHandlerError.communicationFailure
		}
		
		let accountNames = extensionContainers.accounts.map { $0.name }
		return accountNames
	}

	public func resolveAccountName(for intent: AddWebFeedIntent) async -> AddWebFeedAccountNameResolutionResult {
		guard let accountName = intent.accountName else {
			return .notRequired()
		}
		
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			return .unsupported(forReason: .communication)
		}
		if extensionContainers.findAccount(forName: accountName) == nil {
			return .unsupported(forReason: .invalid)
		}

		return .success(with: accountName)
	}

	public func provideFolderNameOptions(for intent: AddWebFeedIntent) async throws -> [String] {
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			throw AddWebFeedIntentHandlerError.communicationFailure
		}

		guard let accountName = intent.accountName, let account = extensionContainers.findAccount(forName: accountName) else {
			return [String]()
		}

		let folderNames = account.folders.map { $0.name }
		return folderNames
	}

	public func resolveFolderName(for intent: AddWebFeedIntent) async -> AddWebFeedFolderNameResolutionResult {
		guard let accountName = intent.accountName, let folderName = intent.folderName else {
			return .notRequired()
		}

		guard let extensionContainers = await ExtensionContainersFile.read() else {
			return .unsupported(forReason: .communication)
		}
		guard let account = extensionContainers.findAccount(forName: accountName) else {
			return .unsupported(forReason: .invalid)
		}

		let folder = account.findFolder(forName: folderName)
		if folder == nil {
			return .unsupported(forReason: .invalid)
		}

		return .success(with: folderName)
	}

	public func handle(intent: AddWebFeedIntent) async -> AddWebFeedIntentResponse {
		guard let url = intent.url, let extensionContainers = await ExtensionContainersFile.read() else {
			return AddWebFeedIntentResponse(code: .failure, userActivity: nil)
		}

		let account: ExtensionAccount? = {
			if let accountName = intent.accountName {
				return extensionContainers.findAccount(forName: accountName)
			} else {
				return extensionContainers.accounts.first
			}
		}()

		guard let validAccount = account else {
			return AddWebFeedIntentResponse(code: .failure, userActivity: nil)
		}

		let container: ExtensionContainer? = {
			if let folderName = intent.folderName {
				return validAccount.findFolder(forName: folderName)
			} else {
				return validAccount
			}
		}()

		guard let validContainer = container, let containerID = validContainer.containerID else {
			return AddWebFeedIntentResponse(code: .failure, userActivity: nil)
		}

		let request = ExtensionFeedAddRequest(name: nil, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)
		return AddWebFeedIntentResponse(code: .success, userActivity: nil)
	}
}
