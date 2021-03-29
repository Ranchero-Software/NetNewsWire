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

enum AddFeedType {
	case web
	case reddit
	case twitter
}

class AddFeedViewController: UITableViewController {
	
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var urlTextField: UITextField!
	@IBOutlet weak var urlTextFieldToSuperViewConstraint: NSLayoutConstraint!
	@IBOutlet weak var nameTextField: UITextField!
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)
	
	private var folderLabel = ""
	private var userCancelled = false

	var addFeedType = AddFeedType.web
	var initialFeed: String?
	var initialFeedName: String?

	var container: Container?
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		switch addFeedType {
		case .reddit:
			navigationItem.title = NSLocalizedString("Add Reddit Feed", comment: "Add Reddit Feed")
			navigationItem.leftBarButtonItem = nil
		case .twitter:
			navigationItem.title = NSLocalizedString("Add Twitter Feed", comment: "Add Twitter Feed")
			navigationItem.leftBarButtonItem = nil
		default:
			break
		}
		
		activityIndicator.isHidden = true
		activityIndicator.color = .label
		
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
			addButton.isEnabled = true
		}
		
		nameTextField.text = initialFeedName
		nameTextField.delegate = self
		
		if let defaultContainer = AddWebFeedDefaultContainer.defaultContainer {
			container = defaultContainer
		} else {
			addButton.isEnabled = false
		}
		
		updateFolderLabel()
		
		tableView.register(UINib(nibName: "AddFeedSelectFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "AddFeedSelectFolderTableViewCell")

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: urlTextField)
		
		if initialFeed == nil {
			urlTextField.becomeFirstResponder()
		}
	}
	
	@IBAction func cancel(_ sender: Any) {
		userCancelled = true
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = urlString.normalizedURL
		
		guard !normalizedURLString.isEmpty, let url = URL(unicodeString: normalizedURLString) else {
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
		
		addButton.isEnabled = false
		activityIndicator.isHidden = false
		activityIndicator.startAnimating()
		
		let feedName = (nameTextField.text?.isEmpty ?? true) ? nil : nameTextField.text
		
		BatchUpdate.shared.start()
		
		account!.createWebFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: true) { result in

			BatchUpdate.shared.end()
			
			switch result {
			case .success(let feed):
				self.dismiss(animated: true)
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
			case .failure(let error):
				self.addButton.isEnabled = true
				self.activityIndicator.isHidden = true
				self.activityIndicator.stopAnimating()
				self.presentError(error)
			}

		}

	}
	
	@objc func textDidChange(_ note: Notification) {
		updateUI()
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.row == 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "AddFeedSelectFolderTableViewCell", for: indexPath) as? AddFeedSelectFolderTableViewCell
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
			let folderViewController = navController.topViewController as! AddFeedFolderViewController
			folderViewController.delegate = self
			folderViewController.addFeedType = addFeedType
			folderViewController.initialContainer = container
			present(navController, animated: true)
		}
	}
	
}

// MARK: AddWebFeedFolderViewControllerDelegate

extension AddFeedViewController: AddFeedFolderViewControllerDelegate {
	func didSelect(container: Container) {
		self.container = container
		updateFolderLabel()
		AddWebFeedDefaultContainer.saveDefaultContainer(container)
	}
}

// MARK: UITextFieldDelegate

extension AddFeedViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}

// MARK: Private

private extension AddFeedViewController {
	
	func updateUI() {
		addButton.isEnabled = (urlTextField.text?.mayBeURL ?? false)
	}
	
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
