//
//  AddFeedAppIntent.swift
//  NetNewsWire-iOS
//
//  Modern App Intents replacement for the legacy SiriKit "Add Feed" intent.
//  <https://github.com/Ranchero-Software/NetNewsWire/issues/5248>
//

import Foundation
import AppIntents

struct AddFeedAppIntent: AppIntent {

	static let title: LocalizedStringResource = "Add Feed"
	static let description = IntentDescription("Adds a feed to NetNewsWire.")

	// Runs in the background: like the Share Extension, this only enqueues a request into the
	// app group; the main app turns it into an actual feed the next time it processes the queue.
	static let openAppWhenRun = false

	@Parameter(title: "URL")
	var url: URL

	@Parameter(title: "Account", optionsProvider: AccountNameOptionsProvider())
	var accountName: String?

	@Parameter(title: "Folder", optionsProvider: FolderNameOptionsProvider())
	var folderName: String?

	static var parameterSummary: some ParameterSummary {
		Summary("Add \(\.$url) to \(\.$accountName)") {
			\.$folderName
		}
	}

	func perform() async throws -> some IntentResult & ProvidesDialog {
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			throw AddFeedAppIntentError.noAccounts
		}

		let account: ExtensionAccount?
		if let accountName {
			account = extensionContainers.findAccount(forName: accountName)
		} else {
			account = extensionContainers.accounts.first
		}
		guard let account else {
			throw AddFeedAppIntentError.noAccounts
		}

		// Resolve the destination container: the named folder if it exists in this account;
		// otherwise the account itself — but substitute its first folder when the account
		// disallows feeds at the root (mirrors AddFeedDefaultContainer.substituteContainerIfNeeded).
		// Not hard-failing on an unknown folder name also covers cross-account name mismatches.
		let container: ExtensionContainer
		if let folderName, let folder = account.findFolder(forName: folderName) {
			container = folder
		} else if account.disallowFeedInRootFolder, let firstFolder = account.folders.first {
			container = firstFolder
		} else {
			container = account
		}

		guard let containerID = container.containerID else {
			throw AddFeedAppIntentError.noContainer
		}

		let request = ExtensionFeedAddRequest(name: nil, feedURL: url, destinationContainerID: containerID)
		ExtensionFeedAddRequestFile.save(request)

		// Neutral wording: the feed is queued here and actually created when the app next runs.
		return .result(dialog: "Adding \(url.absoluteString) to NetNewsWire.")
	}
}

enum AddFeedAppIntentError: Error, CustomLocalizedStringResourceConvertible {
	case noAccounts
	case noContainer

	var localizedStringResource: LocalizedStringResource {
		switch self {
		case .noAccounts:
			return "There are no accounts to add the feed to."
		case .noContainer:
			return "Couldn’t find a place to add the feed."
		}
	}
}

struct AccountNameOptionsProvider: DynamicOptionsProvider {
	func results() async throws -> [String] {
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			return []
		}
		return extensionContainers.accounts.map { $0.name }
	}
}

struct FolderNameOptionsProvider: DynamicOptionsProvider {

	// Scope folder options to the account the user picked (falls back to all accounts' folders
	// when no account is chosen yet).
	@IntentParameterDependency<AddFeedAppIntent>(\.$accountName)
	var addFeedIntent

	func results() async throws -> [String] {
		guard let extensionContainers = await ExtensionContainersFile.read() else {
			return []
		}

		let accounts: [ExtensionAccount]
		if let accountName = addFeedIntent?.accountName, let account = extensionContainers.findAccount(forName: accountName) {
			accounts = [account]
		} else {
			accounts = extensionContainers.accounts
		}

		// Dedupe: folder names can repeat across accounts when unscoped.
		var seen = Set<String>()
		return accounts.flatMap { $0.folders.map { $0.name } }.filter { seen.insert($0).inserted }
	}
}
