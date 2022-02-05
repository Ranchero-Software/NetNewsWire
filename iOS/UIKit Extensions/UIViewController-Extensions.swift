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
		} else if let decodingError = error as? DecodingError {
			let errorTitle = NSLocalizedString("ERROR", comment: "Error")
			var informativeText: String = ""
			switch decodingError {
			case .typeMismatch(let type, _):
				let localizedError = NSLocalizedString("THEME_INFOPLIST_MISMATCH", comment: "Type mismatch")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, type as! CVarArg) as String
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .valueNotFound(let value, _):
				let localizedError = NSLocalizedString("THEME_INFOPLIST_MISSING_VALUE", comment: "Decoding value missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, value as! CVarArg) as String
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .keyNotFound(let codingKey, _):
				let localizedError = NSLocalizedString("THEME_INFOPLIST_MISSING_KEY", comment: "Decoding key missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, codingKey.stringValue) as String
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .dataCorrupted(let context):
				guard let error = context.underlyingError as NSError?,
					  let debugDescription = error.userInfo["NSDebugDescription"] as? String else {
					informativeText = error.localizedDescription
					presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
					return
				}
				let localizedError = NSLocalizedString("THEME_INFOPLIST_DATA_CORRUPTION", comment: "Decoding key missing")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, debugDescription) as String
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
				
			default:
				informativeText = error.localizedDescription
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			}
		} else {
			let errorTitle = NSLocalizedString("ERROR", comment: "Error")
			presentError(title: errorTitle, message: error.localizedDescription, dismiss: dismiss)
		}
	}

}

private extension UIViewController {
	
	func presentAccountError(_ error: AccountError, dismiss: (() -> Void)? = nil) {
		let title = NSLocalizedString("ACCOUNT_ERROR", comment: "Account Error")
		let alertController = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
		
		if error.account?.type == .feedbin {

			let credentialsTitle = NSLocalizedString("UPDATE_CREDENTIALS", comment: "Update Credentials")
			let credentialsAction = UIAlertAction(title: credentialsTitle, style: .default) { [weak self] _ in
				dismiss?()
				
				let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
				navController.modalPresentationStyle = .formSheet
				let addViewController = navController.topViewController as! FeedbinAccountViewController
				addViewController.account = error.account
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
