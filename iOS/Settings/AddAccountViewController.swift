//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit
import RSCore

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	#if DEBUG
	private var addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly, .feedWrangler, .cloudKit, .newsBlur]
	#else
	private var addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly]
	#endif

	override func viewDidLoad() {
		super.viewDidLoad()
		restrictAccounts()
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return addableAccountTypes.count
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 52.0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsAccountTableViewCell", for: indexPath) as! SettingsAccountTableViewCell
		
		switch addableAccountTypes[indexPath.row] {
		case .onMyMac:
			cell.accountNameLabel?.text = Account.defaultLocalAccountName
			cell.accountImage?.image = AppAssets.image(for: .onMyMac)
		case .cloudKit:
			cell.accountNameLabel?.text = NSLocalizedString("iCloud", comment: "iCloud")
			cell.accountImage?.image = AppAssets.accountCloudKitImage
		case .feedbin:
			cell.accountNameLabel?.text = NSLocalizedString("Feedbin", comment: "Feedbin")
			cell.accountImage?.image = AppAssets.accountFeedbinImage
		case .feedWrangler:
			cell.accountNameLabel?.text = NSLocalizedString("Feed Wrangler", comment: "Feed Wrangler")
			cell.accountImage?.image = AppAssets.accountFeedWranglerImage
		case .feedly:
			cell.accountNameLabel?.text = NSLocalizedString("Feedly", comment: "Feedly")
			cell.accountImage?.image = AppAssets.accountFeedlyImage
		case .newsBlur:
			cell.accountNameLabel?.text = NSLocalizedString("NewsBlur", comment: "NewsBlur")
			cell.accountImage?.image = AppAssets.accountNewsBlurImage
		default:
			break
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch addableAccountTypes[indexPath.row] {
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
			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			MainThreadOperationQueue.shared.add(addAccount)
		case .feedWrangler:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedWranglerAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! FeedWranglerAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case .newsBlur:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "NewsBlurAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! NewsBlurAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		default:
			break
		}
	}
	
	func dismiss() {
		navigationController?.popViewController(animated: false)
	}
	
}

extension AddAccountViewController: OAuthAccountAuthorizationOperationDelegate {
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		let rootViewController = view.window?.rootViewController
		
		account.refreshAll { result in
			switch result {
			case .success:
				break
			case .failure(let error):
				guard let viewController = rootViewController else {
					return
				}
				viewController.presentError(error)
			}
		}
		
		dismiss()
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		presentError(error)
	}
}

// MARK: Private

private extension AddAccountViewController {
	
	func restrictAccounts() {
		func removeAccountType(_ accountType: AccountType) {
			if let index = addableAccountTypes.firstIndex(of: accountType) {
				addableAccountTypes.remove(at: index)
			}
		}
		
		if AppDefaults.isDeveloperBuild {
			removeAccountType(.cloudKit)
			removeAccountType(.feedly)
			removeAccountType(.feedWrangler)
			return
		}

		if AccountManager.shared.activeAccounts.firstIndex(where: { $0.type == .cloudKit }) != nil {
			removeAccountType(.cloudKit)
		}
	}
	
}
