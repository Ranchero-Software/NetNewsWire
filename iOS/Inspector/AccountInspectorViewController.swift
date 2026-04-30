//
//  AccountInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/17/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import SafariServices
import RSCore
import Account

final class AccountInspectorViewController: UITableViewController {
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

	@IBOutlet var nameTextField: UITextField!
	@IBOutlet var activeSwitch: UISwitch!
	@IBOutlet var deleteAccountButton: VibrantButton!
	@IBOutlet var syncContentSwitch: UISwitch!
	@IBOutlet var limitationsAndSolutionsButton: UIButton!

	var isModal = false
	weak var account: Account?

    override func viewDidLoad() {
        super.viewDidLoad()

		guard let account = account else { return }

		nameTextField.placeholder = account.defaultName
		nameTextField.text = account.name
		nameTextField.delegate = self
		activeSwitch.isOn = account.isActive
		syncContentSwitch.isOn = AccountManager.shared.syncArticleContentForUnreadArticles

		navigationItem.title = account.nameForDisplay

		if account.type != .onMyMac {
			deleteAccountButton.setTitle(NSLocalizedString("Remove Account", comment: "Remove Account"), for: .normal)
		}

		if account.type != .cloudKit {
			limitationsAndSolutionsButton.isHidden = true
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

	@IBAction func syncContentSwitchDidChange(_ sender: UISwitch) {
		AccountManager.shared.syncArticleContentForUnreadArticles = sender.isOn
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
		let markAction = UIAlertAction(title: markTitle, style: .destructive) { [weak self] _ in
			guard let self, let account = self.account else {
				return
			}
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

	@IBAction func openLimitationsAndSolutions(_ sender: Any) {
		let vc = SFSafariViewController(url: CloudKitWebDocumentation.limitationsAndSolutionsURL)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}

// MARK: - Table View

extension AccountInspectorViewController {

	/// Sections as laid out in the storyboard.
	enum StoryboardSection: Int {
		case nameAndActive = 0
		case credentials = 1
		case deleteAccount = 2
		case syncContent = 3
	}

	var isCloudKitAccount: Bool {
		account?.type == .cloudKit
	}

	var hidesCredentialsSection: Bool {
		guard let account else {
			return true
		}
		switch account.type {
		case .onMyMac, .cloudKit, .feedly:
			return true
		default:
			return false
		}
	}

	/// The storyboard sections to display, in order, for the current account type.
	///
	/// - Default account: name/active only
	/// - cloudKit: name/active, sync content, delete
	/// - Other hidden-credentials: name/active, delete
	/// - All others: name/active, credentials, delete
	var displayedSections: [StoryboardSection] {
		guard let account else {
			return []
		}
		if account == AccountManager.shared.defaultAccount {
			return [.nameAndActive]
		}
		if isCloudKitAccount {
			return [.nameAndActive, .syncContent, .deleteAccount]
		}
		if hidesCredentialsSection {
			return [.nameAndActive, .deleteAccount]
		}
		return [.nameAndActive, .credentials, .deleteAccount]
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		displayedSections.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let storyboardIndex = displayedSections[section].rawValue
		return super.tableView(tableView, numberOfRowsInSection: storyboardIndex)
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if displayedSections[section] == .nameAndActive {
			return ImageHeaderView.rowHeight
		}
		let storyboardIndex = displayedSections[section].rawValue
		return super.tableView(tableView, heightForHeaderInSection: storyboardIndex)
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard let account else {
			return nil
		}
		if displayedSections[section] == .nameAndActive {
			let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as! ImageHeaderView
			headerView.imageView.image = Assets.accountImage(account.type)
			return headerView
		}
		let storyboardIndex = displayedSections[section].rawValue
		return super.tableView(tableView, viewForHeaderInSection: storyboardIndex)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let storyboardIndex = displayedSections[indexPath.section].rawValue
		return super.tableView(tableView, cellForRowAt: IndexPath(row: indexPath.row, section: storyboardIndex))
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if displayedSections[section] == .syncContent {
			return NSLocalizedString("Syncing article content increases iCloud storage use, sync time, and battery use.\n\nArticle status and the content of starred articles are always synced.", comment: "Sync content footer text")
		}
		let storyboardIndex = displayedSections[section].rawValue
		return super.tableView(tableView, titleForFooterInSection: storyboardIndex)
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
