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

class AddWebFeedViewController: UITableViewController, AddContainerViewControllerChild {
	
	@IBOutlet private weak var urlTextField: UITextField!
	@IBOutlet private weak var nameTextField: UITextField!
	
	private var folderLabel = ""
	private var userCancelled = false

	weak var delegate: AddContainerViewControllerChildDelegate?
	var initialFeed: String?
	var initialFeedName: String?

	var container: Container?
	
	override func viewDidLoad() {
		
        super.viewDidLoad()
		
		if initialFeed == nil, let urlString = UIPasteboard.general.string {
			if urlString.mayBeURL {
				initialFeed = urlString.normalizedURL
			}
		}
		
		urlTextField.autocorrectionType = .no
		urlTextField.autocapitalizationType = .none
		urlTextField.text = initialFeed
		urlTextField.delegate = self
		
		if initialFeed != nil {
			delegate?.readyToAdd(state: true)
		}
		
		nameTextField.text = initialFeedName
		nameTextField.delegate = self
		
		if let defaultContainer = AddWebFeedDefaultContainer.defaultContainer {
			container = defaultContainer
		} else {
			delegate?.readyToAdd(state: false)
		}
		
		updateFolderLabel()
		
		// I couldn't figure out the gap at the top of the UITableView, so I took a hammer to it.
		tableView.contentInset = UIEdgeInsets(top: -28, left: 0, bottom: 0, right: 0)
		
		tableView.register(UINib(nibName: "AddWebFeedSelectFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "AddWebFeedSelectFolderTableViewCell")

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: urlTextField)

	}
	
	func cancel() {
		userCancelled = true
		delegate?.processingDidCancel()
	}
	
	func add() {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = urlString.normalizedURL
		
		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
			delegate?.processingDidCancel()
			return
		}
		
		guard let container = container else { return }
		
		var account: Account?
		if let containerAccount = container as? Account {
			account = containerAccount
		} else if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
		}
		
		if account!.hasWebFeed(withURL: url.absoluteString) {
			presentError(AccountError.createErrorAlreadySubscribed)
 			return
		}
		
		delegate?.processingDidBegin()
		
		let feedName = (nameTextField.text?.isEmpty ?? true) ? nil : nameTextField.text
		
		BatchUpdate.shared.start()
		
		account!.createWebFeed(url: url.absoluteString, name: feedName, container: container) { result in

			BatchUpdate.shared.end()
			
			switch result {
			case .success(let feed):
				self.delegate?.processingDidEnd()
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
			case .failure(let error):
				self.presentError(error)
				self.delegate?.processingDidCancel()
			}

		}

	}
	
	@objc func textDidChange(_ note: Notification) {
		delegate?.readyToAdd(state: urlTextField.text?.mayBeURL ?? false)
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.row == 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "AddWebFeedSelectFolderTableViewCell", for: indexPath) as? AddWebFeedSelectFolderTableViewCell
			cell!.detailLabel.text = folderLabel
			return cell!
		} else {
			return super.tableView(tableView, cellForRowAt: indexPath)
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.row == 2 {
			let navController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddWebFeedFolderNavViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let folderViewController = navController.topViewController as! AddWebFeedFolderViewController
			folderViewController.delegate = self
			folderViewController.initialContainer = container
			present(navController, animated: true)
		}
	}
	
}

// MARK: AddWebFeedFolderViewControllerDelegate

extension AddWebFeedViewController: AddWebFeedFolderViewControllerDelegate {
	func didSelect(container: Container) {
		self.container = container
		updateFolderLabel()
		AddWebFeedDefaultContainer.saveDefaultContainer(container)
	}
}

// MARK: UITextFieldDelegate

extension AddWebFeedViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}

// MARK: Private

private extension AddWebFeedViewController {
	func updateFolderLabel() {
		if let containerName = (container as? DisplayNameProvider)?.nameForDisplay {
			if container is Folder {
				folderLabel = "\(container?.account?.nameForDisplay ?? "") / \(containerName)"
			} else {
				folderLabel = containerName
			}
			tableView.reloadData()
		}
	}
}
