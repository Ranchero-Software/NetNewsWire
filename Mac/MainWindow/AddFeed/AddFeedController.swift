//
//  AddFeedController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSCoreResources
import RSTree
import Articles
import Account
import RSParser

// Run add-feed sheet.
// If it returns with URL and optional name,
//   run FeedFinder plus modal progress window.
//   If FeedFinder returns feed,
//      add feed.
//   Else,
//      display error sheet.

@MainActor final class AddFeedController: AddFeedWindowControllerDelegate {
	private let hostWindow: NSWindow
	private var addFeedWindowController: AddFeedWindowController?
	private var foundFeedURLString: String?
	private var titleFromFeed: String?

	init(hostWindow: NSWindow) {
		self.hostWindow = hostWindow
	}

	func showAddFeedSheet(_ urlString: String? = nil, _ name: String? = nil, _ account: Account? = nil, _ folder: Folder? = nil) {
		let folderTreeControllerDelegate = FolderTreeControllerDelegate()
		let folderTreeController = TreeController(delegate: folderTreeControllerDelegate)

		let windowController = AddFeedWindowController(urlString: urlString ?? urlStringFromPasteboard,
													   name: name,
													   account: account,
													   folder: folder,
													   folderTreeController: folderTreeController,
													   delegate: self)
		addFeedWindowController = windowController
		windowController.runSheetOnWindow(hostWindow)
	}

	// MARK: - AddFeedWindowControllerDelegate

	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL url: URL, userEnteredTitle title: String?, container: Container) {
		closeAddFeedSheet(NSApplication.ModalResponse.OK)

		guard let accountAndFolderSpecifier = accountAndFolderFromContainer(container) else {
			return
		}
		let account = accountAndFolderSpecifier.account

		if let existingFeed = account.existingFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError(existingFeed, account: account)
			return
		}

		account.createFeed(url: url.absoluteString, name: title, container: container, validateFeed: true) { result in

			DispatchQueue.main.async {
				self.endShowingProgress()
			}

			switch result {
			case .success(let feed):
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
			case .failure(let error):
				switch error {
				case AccountError.createErrorAlreadySubscribed:
					self.showAlreadySubscribedError(account.existingFeed(withURL: url.absoluteString), account: account)
				case AccountError.createErrorNotFound:
					self.showNoFeedsErrorMessage()
				default:
					DispatchQueue.main.async {
						NSApplication.shared.presentError(error)
					}
				}
			}

		}

		beginShowingProgress()
	}

	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController) {
		closeAddFeedSheet(NSApplication.ModalResponse.cancel)
	}
}

private extension AddFeedController {
	var urlStringFromPasteboard: String? {
		if let urlString = NSPasteboard.urlString(from: NSPasteboard.general) {
			return urlString.normalizedURL
		}
		return nil
	}

	struct AccountAndFolderSpecifier {
		let account: Account
		let folder: Folder?
	}

	func accountAndFolderFromContainer(_ container: Container) -> AccountAndFolderSpecifier? {
		if let account = container as? Account {
			return AccountAndFolderSpecifier(account: account, folder: nil)
		}
		if let folder = container as? Folder, let account = folder.account {
			return AccountAndFolderSpecifier(account: account, folder: folder)
		}
		return nil
	}

	func closeAddFeedSheet(_ returnCode: NSApplication.ModalResponse) {
		if let sheetWindow = addFeedWindowController?.window {
			hostWindow.endSheet(sheetWindow, returnCode: returnCode)
		}
	}

	// MARK: - Errors

	func showAlreadySubscribedError(_ feed: Feed?, account: Account) {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Already subscribed", comment: "Feed finder")
		alert.informativeText = alreadySubscribedErrorText(feed, account: account)
		alert.beginSheetModal(for: hostWindow)
	}

	func alreadySubscribedErrorText(_ feed: Feed?, account: Account) -> String {
		let genericText = NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")

		guard let feed else {
			return genericText
		}

		let folderNames = account.existingContainers(withFeed: feed)
			.compactMap { ($0 as? Folder)?.nameForDisplay }
			.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
		if folderNames.isEmpty {
			return genericText
		}

		let quotedNames = folderNames.map { "“\($0)”" }
		let formatString = NSLocalizedString("Can’t add this feed because you’ve already subscribed to it in %@.", comment: "Feed finder")
		return NSString.localizedStringWithFormat(formatString as NSString, quotedNames.formatted(.list(type: .and))) as String
	}

	func showInitialDownloadError(_ error: Error) {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Download Error", comment: "Feed finder")

		let formatString = NSLocalizedString("Can’t add this feed because of a download error: “%@”", comment: "Feed finder")
		let errorText = NSString.localizedStringWithFormat(formatString as NSString, error.localizedDescription)
		alert.informativeText = errorText as String
		alert.beginSheetModal(for: hostWindow)
	}

	func showNoFeedsErrorMessage() {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Unable to Add Feed", comment: "Feed finder")
		alert.informativeText = NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")
		alert.beginSheetModal(for: hostWindow)
	}

	// MARK: - Progress

	func beginShowingProgress() {
		IndeterminateProgressController.beginProgressWithMessage(NSLocalizedString("Finding feed…", comment: "Feed finder"))
	}

	func endShowingProgress() {
		IndeterminateProgressController.endProgress()
		hostWindow.makeKeyAndOrderFront(self)
	}
}
