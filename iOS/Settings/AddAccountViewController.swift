//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	@IBOutlet private weak var localAccountImageView: UIImageView!
	@IBOutlet private weak var localAccountNameLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		localAccountImageView.image = AppAssets.image(for: .onMyMac)
		localAccountNameLabel.text = Account.defaultLocalAccountName
	}
	
	#if !DEBUG
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 3
	}
	#endif
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "AddLocalAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! LocalAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case 1:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! FeedbinAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case 2:
			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
			addAccount.delegate = self
			addAccount.presentationAnchor = self.view.window!
			OperationQueue.main.addOperation(addAccount)
		case 3:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedWranglerAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! FeedWranglerAccountViewController
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
