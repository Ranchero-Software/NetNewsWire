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

class AddFeedController: AddFeedWindowControllerDelegate, FeedFinderDelegate {

	private let hostWindow: NSWindow
	private var addFeedWindowController: AddFeedWindowController?
	private var userEnteredURL: URL?
	private var userEnteredFolder: Folder?
	private var userEnteredTitle: String?
	private var userEnteredAccount: Account?
	private var foundFeedURLString: String?
	private var titleFromFeed: String?
	private var feedFinder: FeedFinder?
	private var isFindingFeed = false
	private var bestFeedSpecifier: FeedSpecifier?
	
	init(hostWindow: NSWindow) {
		
		self.hostWindow = hostWindow
	}

	func showAddFeedSheet(_ urlString: String?, _ name: String?) {

		let folderTreeControllerDelegate = FolderTreeControllerDelegate()

		let rootNode = Node(representedObject: AccountManager.shared.localAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		let folderTreeController = TreeController(delegate: folderTreeControllerDelegate, rootNode: rootNode)

		addFeedWindowController = AddFeedWindowController(urlString: urlString ?? urlStringFromPasteboard, name: name, folderTreeController: folderTreeController, delegate: self)
		addFeedWindowController!.runSheetOnWindow(hostWindow)
	}

	// MARK: AddFeedWindowControllerDelegate

	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL url: URL, userEnteredTitle title: String?, container: Container) {

		closeAddFeedSheet(NSApplication.ModalResponse.OK)

		guard let accountAndFolderSpecifier = accountAndFolderFromContainer(container) else {
			return
		}
		let account = accountAndFolderSpecifier.account
		let folder = accountAndFolderSpecifier.folder

		if account.hasFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError(url.absoluteString)
			return
		}

		userEnteredAccount = account
		userEnteredURL = url
		userEnteredFolder = folder
		userEnteredTitle = title

		findFeed()
	}

	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController) {

		closeAddFeedSheet(NSApplication.ModalResponse.cancel)
	}

	// MARK: FeedFinderDelegate

	public func feedFinder(_ feedFinder: FeedFinder, didFindFeeds feedSpecifiers: Set<FeedSpecifier>) {

		isFindingFeed = false
		endShowingProgress()
		
		if let error = feedFinder.initialDownloadError {
			if feedFinder.initialDownloadStatusCode == 404 {
				showNoFeedsErrorMessage()
			}
			else {
				showInitialDownloadError(error)
			}
			return
		}

		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
			showNoFeedsErrorMessage()
			return
		}

		self.bestFeedSpecifier = bestFeedSpecifier
		self.foundFeedURLString = bestFeedSpecifier.urlString

		if let url = URL(string: bestFeedSpecifier.urlString) {

			InitialFeedDownloader.download(url) { (parsedFeed) in
				self.titleFromFeed = parsedFeed?.title
				self.addFeedIfPossible(parsedFeed)
			}
		}
		else {
			// Shouldn't happen.
			showNoFeedsErrorMessage()
		}
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


	func addFeedIfPossible(_ parsedFeed: ParsedFeed?) {

		// Add feed if not already subscribed-to.

		guard let account = userEnteredAccount else {
			assertionFailure("Expected account.")
			return
		}
		guard let feedURLString = foundFeedURLString else {
			assertionFailure("Expected feedURLString.")
			return
		}

		if account.hasFeed(withURL: feedURLString) {
			showAlreadySubscribedError(feedURLString)
			return
		}

		guard let feed = account.createFeed(with: titleFromFeed, editedName: userEnteredTitle, url: feedURLString) else {
			return
		}

		if let parsedFeed = parsedFeed {
			account.update(feed, with: parsedFeed, {})
		}

		if account.addFeed(feed, to: userEnteredFolder) {
			NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
		}
	}

	// MARK: Find Feeds

	func findFeed() {

		guard let url = userEnteredURL else {
			assertionFailure("Expected userEnteredURL.")
			return
		}
		
		isFindingFeed = true
		feedFinder = FeedFinder(url: url, delegate: self)
		
		beginShowingProgress()
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

