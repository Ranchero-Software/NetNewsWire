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
	
	@IBOutlet private weak var urlTextField: UITextField!
	@IBOutlet private weak var nameTextField: UITextField!
	@IBOutlet private weak var folderPickerView: UIPickerView!
	@IBOutlet private weak var folderLabel: UILabel!
	
	private lazy var pickerData: AddFeedFolderPickerData = AddFeedFolderPickerData()
	private var shouldDisplayPicker: Bool {
		return pickerData.containerNames.count > 1
	}
	
	private var userCancelled = false

	weak var delegate: AddContainerViewControllerChildDelegate?
	var initialFeed: String?
	var initialFeedName: String?

	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		urlTextField.text = initialFeed
		urlTextField.delegate = self
		
		if initialFeed != nil {
			delegate?.readyToAdd(state: true)
		}
		
		nameTextField.text = initialFeedName
		nameTextField.delegate = self
		folderLabel.text = pickerData.containerNames.first
		
		if shouldDisplayPicker {
			folderPickerView.dataSource = self
			folderPickerView.delegate = self
			folderPickerView.showsSelectionIndicator = true
		} else {
			folderPickerView.isHidden = true
		}
		
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
		
		let container = pickerData.containers[folderPickerView.selectedRow(inComponent: 0)]
		
		var account: Account?
		var folder: Folder?
		if let containerAccount = container as? Account {
			account = containerAccount
		}
		if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
			folder = containerFolder
		}
		
		if account!.hasFeed(withURL: url.absoluteString) {
			showAlreadySubscribedError()
 			return
		}
		
		let title = nameTextField.text
		
		delegate?.processingDidBegin()

		account!.createFeed(url: url.absoluteString) { [weak self] result in
			
			switch result {
			case .success(let feed):
				self?.processFeed(feed, account: account!, folder: folder, url: url, title: title)
			case .failure(let error):
				switch error {
				case AccountError.createErrorAlreadySubscribed:
					self?.showAlreadySubscribedError()
					self?.delegate?.processingDidCancel()
				case AccountError.createErrorNotFound:
					self?.showNoFeedsErrorMessage()
					self?.delegate?.processingDidCancel()
				default:
					self?.presentError(error)
					self?.delegate?.processingDidCancel()
				}
			}

		}

	}
	
	@objc func textDidChange(_ note: Notification) {
		delegate?.readyToAdd(state: urlTextField.text?.rs_stringMayBeURL() ?? false)
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 1 {
			return shouldDisplayPicker ? 2 : 1
		}
		
		return super.tableView(tableView, numberOfRowsInSection: section)
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
	
	func processFeed(_ feed: Feed, account: Account, folder: Folder?, url: URL, title: String?) {
		
		if let title = title {
			account.renameFeed(feed, to: title) { [weak self] result in
				switch result {
				case .success:
					break
				case .failure(let error):
					self?.presentError(error)
				}
			}
		}
		
		if let folder = folder {
			folder.addFeed(feed) { [weak self] result in
				switch result {
				case .success:
					self?.delegate?.processingDidEnd()
					NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
				case .failure(let error):
					self?.delegate?.processingDidEnd()
					self?.presentError(error)
				}
			}
		} else {
			account.addFeed(feed) { [weak self] result in
				switch result {
				case .success:
					self?.delegate?.processingDidEnd()
					NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
				case .failure(let error):
					self?.delegate?.processingDidEnd()
					self?.presentError(error)
				}
			}
		}
		
	}
	
}

extension AddFeedViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
