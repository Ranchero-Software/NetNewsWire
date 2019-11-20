//
//  AddFeedController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
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

class AddFeedController: AddFeedWindowControllerDelegate {

	private let hostWindow: NSWindow
	private var addFeedWindowController: AddFeedWindowController?
	private var foundFeedURLString: String?
	private var titleFromFeed: String?
	
	init(hostWindow: NSWindow) {
		
		self.hostWindow = hostWindow
	}

	func showAddFeedSheet(_ urlString: String?, _ name: String?, _ account: Account?, _ folder: Folder?) {

		let folderTreeControllerDelegate = FolderTreeControllerDelegate()
		let folderTreeController = TreeController(delegate: folderTreeControllerDelegate)

		addFeedWindowController = AddFeedWindowController(urlString: urlString ?? urlStringFromPasteboard, name: name, account: account, folder: folder, folderTreeController: folderTreeController, delegate: self)
		addFeedWindowController!.runSheetOnWindow(hostWindow)
	}

	// MARK: AddFeedWindowControllerDelegate

	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL url: URL, userEnteredTitle title: String?, container: Container) {

		closeAddFeedSheet(NSApplication.ModalResponse.OK)

		guard let accountAndFolderSpecifier = accountAndFolderFromContainer(container) else {
			return
		}
		let account = accountAndFolderSpecifier.account

		if account.hasWebFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError(url.absoluteString)
			return
		}

		BatchUpdate.shared.start()
		
		account.createWebFeed(url: url.absoluteString, name: title, container: container) { result in
			
			DispatchQueue.main.async {
				self.endShowingProgress()
			}
			
			BatchUpdate.shared.end()

			switch result {
			case .success(let feed):
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
			case .failure(let error):
				switch error {
				case AccountError.createErrorAlreadySubscribed:
					self.showAlreadySubscribedError(url.absoluteString)
				case AccountError.createErrorNotFound:
					self.showNoFeedsErrorMessage()
				default:
					NSApplication.shared.presentError(error)
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
		if let urlString = NSPasteboard.rs_urlString(from: NSPasteboard.general) {
			return urlString.rs_normalizedURL()
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

	// MARK: Errors

	func showAlreadySubscribedError(_ urlString: String) {

		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Already subscribed", comment: "Feed finder")
		alert.informativeText = NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")

		alert.beginSheetModal(for: hostWindow)
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
		alert.messageText = NSLocalizedString("Feed not found", comment: "Feed finder")
		alert.informativeText = NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")

		alert.beginSheetModal(for: hostWindow)
	}

	// MARK: Progress

	func beginShowingProgress() {
		
		runIndeterminateProgressWithMessage(NSLocalizedString("Finding feed…", comment:"Feed finder"))
	}
	
	func endShowingProgress() {
		
		stopIndeterminateProgress()
		hostWindow.makeKeyAndOrderFront(self)
	}
}

