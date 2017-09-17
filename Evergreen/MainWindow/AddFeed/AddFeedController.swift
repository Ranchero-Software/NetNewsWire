//
//  AddFeedController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import RSCore
import RSTree
import Data
import RSFeedFinder
import Account

// Run add-feed sheet.
// If it returns with URL and optional name,
//   run FeedFinder plus modal progress window.
//   If FeedFinder returns feed,
//      add feed.
//   Else,
//      display error sheet.

let UserDidAddFeedNotification = Notification.Name("UserDidAddFeedNotification")
let UserDidAddFeedKey = "feed"

class AddFeedController: AddFeedWindowControllerDelegate, FeedFinderDelegate {

	fileprivate let hostWindow: NSWindow
	fileprivate var addFeedWindowController: AddFeedWindowController?
	fileprivate var userEnteredURL: URL?
	fileprivate var userEnteredFolder: Folder?
	fileprivate var userEnteredTitle: String?
	fileprivate var foundFeedURLString: String?
	fileprivate var titleFromFeed: String?
	fileprivate var feedFinder: FeedFinder?
	fileprivate var isFindingFeed = false
	fileprivate var bestFeedSpecifier: FeedSpecifier?
	
	init(hostWindow: NSWindow) {
		
		self.hostWindow = hostWindow
	}

	func showAddFeedSheet(_ urlString: String?, _ name: String?) {

		let folderTreeControllerDelegate = FolderTreeControllerDelegate()

		let rootNode = Node(representedObject: AccountManager.sharedInstance.localAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		let folderTreeController = TreeController(delegate: folderTreeControllerDelegate, rootNode: rootNode)

		addFeedWindowController = AddFeedWindowController(urlString: urlString ?? urlStringFromPasteboard, name: name, folderTreeController: folderTreeController, delegate: self)
		addFeedWindowController!.runSheetOnWindow(hostWindow)
	}

	// MARK: AddFeedWindowControllerDelegate

	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL url: URL, userEnteredTitle title: String?, folder: Folder) {

		closeAddFeedSheet(NSApplication.ModalResponse.OK)

		assert(folder.account != nil, "Folder must have an account.")
		let account = folder.account ?? AccountManager.sharedInstance.localAccount

		if account.hasFeedWithURLString(url.absoluteString) {
			showAlreadySubscribedError(url.absoluteString, folder)
			return
		}

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

		if let _ = userEnteredTitle {
			addFeedIfPossible()
		}

		if let url = URL(string: bestFeedSpecifier.urlString) {

			downloadTitleForFeed(url, { (title) in
				self.titleFromFeed = title
				self.addFeedIfPossible()
			})
		}
		else {
			// Shouldn't happen.
			showNoFeedsErrorMessage()
		}
	}
}


private extension AddFeedController {

	var urlStringFromPasteboard: String? {
		get {
			if let urlString = NSPasteboard.rs_urlString(from: NSPasteboard.general) {
				return urlString.rs_normalizedURL()
			}
			return nil
		}
	}

	func closeAddFeedSheet(_ returnCode: NSApplication.ModalResponse) {

		if let sheetWindow = addFeedWindowController?.window {
			hostWindow.endSheet(sheetWindow, returnCode: returnCode)
		}
	}


	func addFeedIfPossible() {

		// Add feed if not already subscribed-to.

		guard let folder = userEnteredFolder else {
			assertionFailure("Folder must not be nil here.")
			return
		}
		guard let account = userEnteredFolder?.account else {
			assertionFailure("Folder must have an account.")
			return
		}
		guard let feedURLString = foundFeedURLString else {
			assertionFailure("urlString must not be nil here.")
			return
		}

		if account.hasFeedWithURLString(feedURLString) {
			showAlreadySubscribedError(feedURLString, folder)
			return
		}

		if let feed = folder.createFeedWithName(titleFromFeed, editedName: userEnteredTitle, urlString: feedURLString) {
			print(feedURLString)
			if folder.addItem(feed) {
				NotificationCenter.default.post(name: UserDidAddFeedNotification, object: self, userInfo: [UserDidAddFeedKey: feed])
			}
		}
	}

	// MARK: Find Feeds

	func findFeed() {

		guard let url = userEnteredURL else {
			assertionFailure("userEnteredURL must not be nil.")
			return
		}
		
		isFindingFeed = true
		feedFinder = FeedFinder(url: url, delegate: self)
		
		beginShowingProgress()
	}

	// MARK: Errors

	func showAlreadySubscribedError(_ urlString: String, _ folder: Folder) {

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

