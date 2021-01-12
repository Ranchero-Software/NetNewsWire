//
//  UIViewController-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/16/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account

extension UIViewController {
	
	func presentError(_ error: Error, dismiss: (() -> Void)? = nil) {
		if let accountError = error as? AccountError, accountError.isCredentialsError {
			presentAccountError(accountError, dismiss: dismiss)
		} else {
			let errorTitle = NSLocalizedString("Error", comment: "Error")
			presentError(title: errorTitle, message: error.localizedDescription, dismiss: dismiss)
		}
	}

}

private extension UIViewController {
	
	func presentAccountError(_ error: AccountError, dismiss: (() -> Void)? = nil) {
		let title = NSLocalizedString("Account Error", comment: "Account Error")
		let alertController = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
		
		if error.acount?.type == .feedbin {

			let credentialsTitle = NSLocalizedString("Update Credentials", comment: "Update Credentials")
			let credentialsAction = UIAlertAction(title: credentialsTitle, style: .default) { [weak self] _ in
				dismiss?()
				
				let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
				navController.modalPresentationStyle = .formSheet
				let addViewController = navController.topViewController as! FeedbinAccountViewController
				addViewController.account = error.acount
				self?.present(navController, animated: true)
			}
			
			alertController.addAction(credentialsAction)
			alertController.preferredAction = credentialsAction

		}
		
		let dismissTitle = NSLocalizedString("OK", comment: "OK")
		let dismissAction = UIAlertAction(title: dismissTitle, style: .default) { _ in
			dismiss?()
		}
		alertController.addAction(dismissAction)
		
		self.present(alertController, animated: true, completion: nil)
	}

}
