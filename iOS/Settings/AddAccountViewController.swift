//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit
import SwiftUI
import RSCore

final class AddAccountViewController: UITableViewController {

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
			cell.comboNameLabel?.text = AddAccountSections.local.sectionContent[indexPath.row].displayName
			cell.comboImage?.image = Assets.accountImage(.onMyMac)
		case AddAccountSections.icloud.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.icloud.sectionContent[indexPath.row].displayName
			cell.comboImage?.image = Assets.accountImage(AddAccountSections.icloud.sectionContent[indexPath.row])
			if AppDefaults.shared.isDeveloperBuild || AccountManager.shared.hasiCloudAccount {
				cell.isUserInteractionEnabled = false
				cell.comboNameLabel?.isEnabled = false
			}
		case AddAccountSections.web.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.web.sectionContent[indexPath.row].displayName
			cell.comboImage?.image = Assets.accountImage(AddAccountSections.web.sectionContent[indexPath.row])
			let type = AddAccountSections.web.sectionContent[indexPath.row]
			if (type == .feedly || type == .inoreader) && AppDefaults.shared.isDeveloperBuild {
				cell.isUserInteractionEnabled = false
				cell.comboNameLabel?.isEnabled = false
			}
		case AddAccountSections.selfhosted.rawValue:
			cell.comboNameLabel?.text = AddAccountSections.selfhosted.sectionContent[indexPath.row].displayName
			cell.comboImage?.image = Assets.accountImage(AddAccountSections.selfhosted.sectionContent[indexPath.row])

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
			presentAccountSheet(LocalAccountView(didAddAccount: { [weak self] in
				self?.didAddAccount()
			}))
		case .cloudKit:
			presentAccountSheet(CloudKitAccountView(didAddAccount: { [weak self] in
				self?.didAddAccount()
			}))
		case .feedbin, .newsBlur, .bazQux, .inoreader, .freshRSS, .theOldReader:
			presentAccountSheet(CredentialsAccountView(accountType: accountType, account: nil, didAddAccount: { [weak self] in
				self?.didAddAccount()
			}))
		case .feedly:
			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			MainThreadOperationQueue.shared.add(addAccount)
		}
	}

	private func presentAccountSheet<Content: View>(_ view: Content) {
		let hostingController = UIHostingController(rootView: view)
		hostingController.modalPresentationStyle = .currentContext
		present(hostingController, animated: true)
	}

	private func didAddAccount() {
		navigationController?.popViewController(animated: false)
	}

}

extension AddAccountViewController: OAuthAccountAuthorizationOperationDelegate {

	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		account.triggerRefreshAll()
		didAddAccount()
	}

	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		presentError(error)
	}
}
