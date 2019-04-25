//
//  AddFeedViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import Account
import RSCore
import RSTree
import RSParser

class AddFeedViewController: UITableViewController, AddContainerViewControllerChild {
	
	@IBOutlet weak var urlTextField: UITextField!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var folderPickerView: UIPickerView!
	@IBOutlet weak var folderLabel: UILabel!
	
	private var pickerData: AddFeedFolderPickerData!
	
	private var feedFinder: FeedFinder?
	private var userEnteredURL: URL?
	private var userEnteredFolder: Folder?
	private var userEnteredTitle: String?
	private var userEnteredAccount: Account?
	private var foundFeedURLString: String?
	private var bestFeedSpecifier: FeedSpecifier?
	private var titleFromFeed: String?

	private var userCancelled = false

	weak var delegate: AddContainerViewControllerChildDelegate?
	var initialFeed: String?
	var initialFeedName: String?

	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		urlTextField.text = initialFeed
		
		if initialFeed != nil {
			delegate?.readyToAdd(state: true)
		}
		
		nameTextField.text = initialFeedName
		
		pickerData = AddFeedFolderPickerData()
		folderPickerView.dataSource = self
		folderPickerView.delegate = self
		folderPickerView.showsSelectionIndicator = true
		folderLabel.text = pickerData.containerNames[0]

		// I couldn't figure out the gap at the top of the UITableView, so I took a hammer to it.
		tableView.contentInset = UIEdgeInsets(top: -28, left: 0, bottom: 0, right: 0)
		
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: urlTextField)

	}
	
	func cancel() {
		userCancelled = true
		delegate?.processingDidCancel()
	}
	
	func add() {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = (urlString as NSString).rs_normalizedURL()
		
		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
			delegate?.processingDidCancel()
			return
		}
		
		userEnteredURL = url
		userEnteredTitle = nameTextField.text

		let container = pickerData.containers[folderPickerView.selectedRow(inComponent: 0)]
		if let account = container as? Account {
			userEnteredAccount = account
		}
		if let folder = container as? Folder, let account = folder.account {
			userEnteredAccount = account
			userEnteredFolder = folder
		}
		
		guard let userEnteredAccount = userEnteredAccount else {
			assertionFailure()
			return
		}
		
		if userEnteredAccount.hasFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError()
 			return
		}
		
		delegate?.processingDidBegin()

		feedFinder = FeedFinder(url: url, delegate: self)

	}
	
	@objc func textDidChange(_ note: Notification) {
		delegate?.readyToAdd(state: urlTextField.text?.rs_stringMayBeURL() ?? false)
	}
	
}

extension AddFeedViewController: UIPickerViewDataSource, UIPickerViewDelegate {
	
	func numberOfComponents(in pickerView: UIPickerView) ->Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return pickerData.containerNames.count
	}
	
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return pickerData.containerNames[row]
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		folderLabel.text = pickerData.containerNames[row]
	}
	
}

extension AddFeedViewController: FeedFinderDelegate {
	
	public func feedFinder(_ feedFinder: FeedFinder, didFindFeeds feedSpecifiers: Set<FeedSpecifier>) {
		
		if userCancelled {
			return
		}
		
		if let error = feedFinder.initialDownloadError {
			if feedFinder.initialDownloadStatusCode == 404 {
				showNoFeedsErrorMessage()
				delegate?.processingDidCancel()
			} else {
				showInitialDownloadError(error)
				delegate?.processingDidCancel()
			}
			return
		}
		
		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
			showNoFeedsErrorMessage()
			delegate?.processingDidCancel()
			return
		}
		
		self.bestFeedSpecifier = bestFeedSpecifier
		self.foundFeedURLString = bestFeedSpecifier.urlString
		
		if let url = URL(string: bestFeedSpecifier.urlString) {
			InitialFeedDownloader.download(url) { (parsedFeed) in
				self.titleFromFeed = parsedFeed?.title
				self.addFeedIfPossible(parsedFeed)
			}
		} else {
			// Shouldn't happen.
			showNoFeedsErrorMessage()
			delegate?.processingDidCancel()
		}
		
	}
	
}

private extension AddFeedViewController {
	
	private func showAlreadySubscribedError() {
		let title = NSLocalizedString("Already subscribed", comment: "Feed finder")
		let message = NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")
		presentError(title: title, message: message)
	}
	
	private func showNoFeedsErrorMessage() {
		let title = NSLocalizedString("Feed not found", comment: "Feed finder")
		let message = NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")
		presentError(title: title, message: message)
	}
	
	private func showInitialDownloadError(_ error: Error) {
		let title = NSLocalizedString("Download Error", comment: "Feed finder")
		let formatString = NSLocalizedString("Can’t add this feed because of a download error: “%@”", comment: "Feed finder")
		let message = NSString.localizedStringWithFormat(formatString as NSString, error.localizedDescription)
		presentError(title: title, message: message as String)
	}
	
	func addFeedIfPossible(_ parsedFeed: ParsedFeed?) {
		
		if userCancelled {
			return
		}

		guard let account = userEnteredAccount else {
			assertionFailure("Expected account.")
			delegate?.processingDidCancel()
			return
		}
		
		guard let feedURLString = foundFeedURLString else {
			assertionFailure("Expected feedURLString.")
			delegate?.processingDidCancel()
			return
		}
		
		if account.hasFeed(withURL: feedURLString) {
			showAlreadySubscribedError()
			delegate?.processingDidCancel()
			return
		}
		
		guard let feed = account.createFeed(with: titleFromFeed, editedName: userEnteredTitle, url: feedURLString) else {
			delegate?.processingDidEnd()
			return
		}
		
		if let parsedFeed = parsedFeed {
			account.update(feed, with: parsedFeed, {})
		}
		
		account.addFeed(feed, to: userEnteredFolder)
		NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
		
		delegate?.processingDidEnd()

	}
	
}
