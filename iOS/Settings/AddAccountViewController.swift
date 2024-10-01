//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit
import Core

protocol AddAccountDismissDelegate: UIViewController {
	
	@MainActor func dismiss()
}

final class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	private enum AddAccountSections: Int, CaseIterable {
		case local = 0
		case icloud
		case web
		case selfhosted
		
		var sectionHeader: String {
			switch self {
			case .local:
				return NSLocalizedString("Local", comment: "Local Account")
			case .icloud:
				return NSLocalizedString("iCloud", comment: "iCloud Account")
			case .web:
				return NSLocalizedString("Web", comment: "Web Account")
			case .selfhosted:
				return NSLocalizedString("Self-hosted", comment: "Self hosted Account")
			}
		}
		
		var sectionFooter: String {
			switch self {
			case .local:
				return NSLocalizedString("Local accounts do not sync your feeds across devices", comment: "Local Account")
			case .icloud:
				return NSLocalizedString("Your iCloud account syncs your feeds across your Mac and iOS devices", comment: "iCloud Account")
			case .web:
				return NSLocalizedString("Web accounts sync your feeds across all your devices", comment: "Web Account")
			case .selfhosted:
				return NSLocalizedString("Self-hosted accounts sync your feeds across all your devices", comment: "Self hosted Account")
			}
		}
		
		var sectionContent: [AccountType] {
			switch self {
			case .local:
				return [.onMyMac]
			case .icloud:
				return [.cloudKit]
			case .web:
				#if DEBUG
				return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
				#else
				return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
				#endif
			case .selfhosted:
				return [.freshRSS]
			}
		}
	}

	private var feedlyAddAccountOperation: FeedlyOAuthAccountAuthorizationOperation?

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return AddAccountSections.allCases.count
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == AddAccountSections.local.rawValue {
			return AddAccountSections.local.sectionContent.count
		}
		
		if section == AddAccountSections.icloud.rawValue {
			return AddAccountSections.icloud.sectionContent.count
		}
		
		if section == AddAccountSections.web.rawValue {
			return AddAccountSections.web.sectionContent.count
		}
		
		if section == AddAccountSections.selfhosted.rawValue {
			return AddAccountSections.selfhosted.sectionContent.count
		}

		return 0
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case AddAccountSections.local.rawValue:
			return AddAccountSections.local.sectionHeader
		case AddAccountSections.icloud.rawValue:
			return AddAccountSections.icloud.sectionHeader
		case AddAccountSections.web.rawValue:
			return AddAccountSections.web.sectionHeader
		case AddAccountSections.selfhosted.rawValue:
			return AddAccountSections.selfhosted.sectionHeader
		default:
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		switch section {
		case AddAccountSections.local.rawValue:
			return AddAccountSections.local.sectionFooter
		case AddAccountSections.icloud.rawValue:
			return AddAccountSections.icloud.sectionFooter
		case AddAccountSections.web.rawValue:
			return AddAccountSections.web.sectionFooter
		case AddAccountSections.selfhosted.rawValue:
			return AddAccountSections.selfhosted.sectionFooter
		default:
			return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsAccountTableViewCell", for: indexPath) as! SettingsComboTableViewCell
		
		switch indexPath.section {
		case AddAccountSections.local.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.local.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = AppAsset.accountImage(for: .onMyMac)
		case AddAccountSections.icloud.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.icloud.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = AppAsset.accountImage(for: AddAccountSections.icloud.sectionContent[indexPath.row])
			if AppDefaults.shared.isDeveloperBuild || AccountManager.shared.accounts.contains(where: { $0.accountType == .cloudKit }) {
				cell.isUserInteractionEnabled = false
				cell.comboNameLabel?.isEnabled = false
			}
		case AddAccountSections.web.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.web.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = AppAsset.accountImage(for: AddAccountSections.web.sectionContent[indexPath.row])
			let type = AddAccountSections.web.sectionContent[indexPath.row]
			if (type == .feedly || type == .inoreader) && AppDefaults.shared.isDeveloperBuild {
				cell.isUserInteractionEnabled = false
				cell.comboNameLabel?.isEnabled = false
			}
		case AddAccountSections.selfhosted.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.selfhosted.sectionContent[indexPath.row].localizedAccountName()
			cell.comboImage?.image = AppAsset.accountImage(for: AddAccountSections.selfhosted.sectionContent[indexPath.row])

		default:
			return cell
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		switch indexPath.section {
		case AddAccountSections.local.rawValue:
			let type = AddAccountSections.local.sectionContent[indexPath.row]
			presentController(for: type)
		case AddAccountSections.icloud.rawValue:
			let type = AddAccountSections.icloud.sectionContent[indexPath.row]
			presentController(for: type)
		case AddAccountSections.web.rawValue:
			let type = AddAccountSections.web.sectionContent[indexPath.row]
			presentController(for: type)
		case AddAccountSections.selfhosted.rawValue:
			let type = AddAccountSections.selfhosted.sectionContent[indexPath.row]
			presentController(for: type)
		default:
			return
		}
	}
	
	private func presentController(for accountType: AccountType) {
		switch accountType {
		case .onMyMac:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "LocalAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! LocalAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .cloudKit:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "CloudKitAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! CloudKitAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .feedbin:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! FeedbinAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .feedly:
			let addAccount = FeedlyOAuthAccountAuthorizationOperation()
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			feedlyAddAccountOperation = addAccount
			
			Task { @MainActor in
				addAccount.run()
			}

		case .newsBlur:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "NewsBlurAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! NewsBlurAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .bazQux, .inoreader, .freshRSS, .theOldReader:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "ReaderAPIAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! ReaderAPIAccountViewController
			addViewController.accountType = accountType
			addViewController.delegate = self
			present(navController, animated: true)
		}
	}
	
	func dismiss() {
		navigationController?.popViewController(animated: false)
	}
	
}

// MARK: - FeedlyOAuthAccountAuthorizationOperationDelegate

extension AddAccountViewController: FeedlyOAuthAccountAuthorizationOperationDelegate {
	
	func oauthAccountAuthorizationOperation(_ operation: FeedlyOAuthAccountAuthorizationOperation, didCreate account: Account) {

		let rootViewController = view.window?.rootViewController

		Task { @MainActor in
			do {
				try await account.refreshAll()
			} catch {
				rootViewController?.presentError(error)
			}
		}

		dismiss()
	}
	
	func oauthAccountAuthorizationOperation(_ operation: FeedlyOAuthAccountAuthorizationOperation, didFailWith error: Error) {
		presentError(error)
	}
}
