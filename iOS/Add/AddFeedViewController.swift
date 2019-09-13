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
	
	private lazy var pickerData: FlattenedAccountFolderPickerData = FlattenedAccountFolderPickerData()
	private var shouldDisplayPicker: Bool {
		return pickerData.containerNames.count > 1
	}
	
	private var userCancelled = false

	weak var delegate: AddContainerViewControllerChildDelegate?
	var initialFeed: String?
	var initialFeedName: String?

	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		if initialFeed == nil, let urlString = UIPasteboard.general.string as NSString? {
			if urlString.rs_stringMayBeURL() {
				initialFeed = urlString.rs_normalizedURL()
			}
		}
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		urlTextField.text = initialFeed
		urlTextField.delegate = self
		urlTextField.becomeFirstResponder()
		
		if initialFeed != nil {
			delegate?.readyToAdd(state: true)
		}
		
		nameTextField.text = initialFeedName
		nameTextField.delegate = self
		folderLabel.text = pickerData.containerNames.first
		
		if shouldDisplayPicker {
			folderPickerView.dataSource = self
			folderPickerView.delegate = self
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
		if let containerAccount = container as? Account {
			account = containerAccount
		} else if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
		}
		
		if account!.hasFeed(withURL: url.absoluteString) {
			presentError(AccountError.createErrorAlreadySubscribed)
 			return
		}
		
		delegate?.processingDidBegin()
		
		let feedName = (nameTextField.text?.isEmpty ?? true) ? nil : nameTextField.text
		
		BatchUpdate.shared.start()
		
		account!.createFeed(url: url.absoluteString, name: feedName, container: container) { result in

			BatchUpdate.shared.end()
			
			switch result {
			case .success(let feed):
				self.delegate?.processingDidEnd()
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
			case .failure(let error):
				self.presentError(error)
				self.delegate?.processingDidCancel()
			}

		}

	}
	
	@objc func textDidChange(_ note: Notification) {
		delegate?.readyToAdd(state: urlTextField.text?.rs_stringMayBeURL() ?? false)
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
		if section == 1 && !shouldDisplayPicker {
			return defaultNumberOfRows - 1
		}
		
		return defaultNumberOfRows
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
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
