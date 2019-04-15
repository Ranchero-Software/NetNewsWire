//Copyright © 2019 Vincode, Inc. All rights reserved.

import UIKit
import Account
import RSCore
import RSTree
import RSParser

class AddFeedViewController: UITableViewController {
	
	@IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet weak var addButton: UIBarButtonItem!
	
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
	
	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		activityIndicatorView.isHidden = true
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		
		pickerData = AddFeedFolderPickerData()
		folderPickerView.dataSource = self
		folderPickerView.delegate = self
		folderLabel.text = pickerData.containerNames[0]
		
    }
	
	@IBAction func cancel(_ sender: Any) {
		userCancelled = true
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = (urlString as NSString).rs_normalizedURL()
		
		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
			dismiss(animated: true)
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
		
		beginShowingProgress()
		
		feedFinder = FeedFinder(url: url, delegate: self)

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

extension AddFeedViewController: UITextFieldDelegate {

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		updateUI()
		return true
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
			updateUI()
	}
	
}

extension AddFeedViewController: FeedFinderDelegate {
	
	public func feedFinder(_ feedFinder: FeedFinder, didFindFeeds feedSpecifiers: Set<FeedSpecifier>) {
		
		if userCancelled {
			endShowingProgress()
			return
		}
		
		if let error = feedFinder.initialDownloadError {
			if feedFinder.initialDownloadStatusCode == 404 {
				endShowingProgress()
				showNoFeedsErrorMessage()
			} else {
				endShowingProgress()
				showInitialDownloadError(error)
			}
			return
		}
		
		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
			endShowingProgress()
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
		} else {
			// Shouldn't happen.
			endShowingProgress()
			showNoFeedsErrorMessage()
		}
		
	}
	
}

private extension AddFeedViewController {
	
	private func updateUI() {
		addButton.isEnabled = urlTextField.text?.rs_stringMayBeURL() ?? false
	}
	
	private func beginShowingProgress() {
		activityIndicatorView.isHidden = false
		activityIndicatorView.startAnimating()
		addButton.isEnabled = false
	}
	
	private func endShowingProgress() {
		activityIndicatorView.isHidden = true
		activityIndicatorView.stopAnimating()
		addButton.isEnabled = true
	}
	
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
			endShowingProgress()
			return
		}

		guard let account = userEnteredAccount else {
			assertionFailure("Expected account.")
			return
		}
		guard let feedURLString = foundFeedURLString else {
			assertionFailure("Expected feedURLString.")
			return
		}
		
		if account.hasFeed(withURL: feedURLString) {
			endShowingProgress()
			showAlreadySubscribedError()
			return
		}
		
		guard let feed = account.createFeed(with: titleFromFeed, editedName: userEnteredTitle, url: feedURLString) else {
			endShowingProgress()
			return
		}
		
		if let parsedFeed = parsedFeed {
			account.update(feed, with: parsedFeed, {})
		}
		
		account.addFeed(feed, to: userEnteredFolder)
		NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
		
		endShowingProgress()
		dismiss(animated: true)
		
	}
	
}

