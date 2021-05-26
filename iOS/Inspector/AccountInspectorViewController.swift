//
//  AccountInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class AccountInspectorViewController: UITableViewController {

	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var activeSwitch: UISwitch!
	@IBOutlet weak var deleteAccountButton: VibrantButton!
	
	var isModal = false
	weak var account: Account?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		guard let account = account else { return }
		
		nameTextField.placeholder = account.defaultName
		nameTextField.text = account.name
		nameTextField.delegate = self
		activeSwitch.isOn = account.isActive
		
		navigationItem.title = account.nameForDisplay
		
		if account.type != .onMyMac {
			deleteAccountButton.setTitle(NSLocalizedString("Remove Account", comment: "Remove Account"), for: .normal) 
		}
		
		if isModal {
			let doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
			navigationItem.leftBarButtonItem = doneBarButtonItem
		}
		
		tableView.register(ImageHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")

	}
	
	override func viewWillDisappear(_ animated: Bool) {
		account?.name = nameTextField.text
		account?.isActive = activeSwitch.isOn
	}

	@objc func done() {
		dismiss(animated: true)
	}
	
	@IBAction func credentials(_ sender: Any) {
		guard let account = account else { return }
		switch account.type {
		case .feedbin:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! FeedbinAccountViewController
			addViewController.account = account
			navController.modalPresentationStyle = .currentContext
			present(navController, animated: true)
		case .feedWrangler:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedWranglerAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! FeedWranglerAccountViewController
			addViewController.account = account
			navController.modalPresentationStyle = .currentContext
			present(navController, animated: true)
		case .newsBlur:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "NewsBlurAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! NewsBlurAccountViewController
			addViewController.account = account
			navController.modalPresentationStyle = .currentContext
			present(navController, animated: true)
		case .inoreader, .bazQux, .theOldReader, .freshRSS:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "ReaderAPIAccountNavigationViewController") as! UINavigationController
			let addViewController = navController.topViewController as! ReaderAPIAccountViewController
			addViewController.accountType = account.type
			addViewController.account = account
			navController.modalPresentationStyle = .currentContext
			present(navController, animated: true)
		default:
			break
		}
	}
	
	@IBAction func deleteAccount(_ sender: Any) {
		guard let account = account else {
			return
		}
		
		let title = NSLocalizedString("Remove Account", comment: "Remove Account")
		let message: String = {
			switch account.type {
			case .feedly:
				return NSLocalizedString("Are you sure you want to remove this account? NetNewsWire will no longer be able to access articles and feeds unless the account is added again.", comment: "Log Out and Remove Account")
			default:
				return NSLocalizedString("Are you sure you want to remove this account? This cannot be undone.", comment: "Remove Account")
			}
		}()
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Remove", comment: "Remove")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in
			guard let self = self, let account = self.account else { return }
			AccountManager.shared.deleteAccount(account)
			if self.isModal {
				self.dismiss(animated: true)
			} else {
				self.navigationController?.popViewController(animated: true)
			}
		}
		alertController.addAction(markAction)
		alertController.preferredAction = markAction
		
		present(alertController, animated: true)
	}
}

// MARK: Table View

extension AccountInspectorViewController {
	
	var hidesCredentialsSection: Bool {
		guard let account = account else {
			return true
		}
		switch account.type {
		case .onMyMac, .cloudKit, .feedly:
			return true
		default:
			return false
		}
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		guard let account = account else { return 0 }
		
		if account == AccountManager.shared.defaultAccount {
			return 1
		} else if hidesCredentialsSection {
			return 2
		} else {
			return super.numberOfSections(in: tableView)
		}
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard let account = account else { return nil }

		if section == 0 {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = AppAssets.image(for: account.type)
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: UITableViewCell
		
		if indexPath.section == 1, hidesCredentialsSection {
			cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 2))
		} else {
			cell = super.tableView(tableView, cellForRowAt: indexPath)
		}
		
		return cell
	}

	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 0 {
			return true
		}
		return false
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
	}
	
}

// MARK: UITextFieldDelegate

extension AccountInspectorViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}
