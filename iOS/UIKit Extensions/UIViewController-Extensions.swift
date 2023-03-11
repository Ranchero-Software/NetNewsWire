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
		if let decodingError = error as? DecodingError {
			let errorTitle = NSLocalizedString("alert.title.error", comment: "Error")
			var informativeText: String = ""
			switch decodingError {
			case .typeMismatch(let type, _):
				let localizedError = NSLocalizedString("alert.message.theme-type-mismatch.%@", comment: "Error message when a type is mismatched. In English, the message is: This theme cannot be used because the the type—“%@”—is mismatched in the Info.plist.")
				informativeText = String.localizedStringWithFormat(localizedError, type as! CVarArg)
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .valueNotFound(let value, _):
				let localizedError = NSLocalizedString("alert.message.theme-value-missing.%@", comment: "Error message when a value is missing. In English, the message is: This theme cannot be used because the the value—“%@”—is not found in the Info.plist.")
				informativeText = String.localizedStringWithFormat(localizedError, value as! CVarArg)
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .keyNotFound(let codingKey, _):
				let localizedError = NSLocalizedString("alert.message.theme-key-missing.%@", comment: "Error message when a key is missing. In English, the message is: This theme cannot be used because the the key—“%@”—is not found in the Info.plist.")
				informativeText = String.localizedStringWithFormat(localizedError, codingKey.stringValue)
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			case .dataCorrupted(let context):
				guard let error = context.underlyingError as NSError?,
					  let debugDescription = error.userInfo["NSDebugDescription"] as? String else {
					informativeText = error.localizedDescription
					presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
					return
				}
				let localizedError = NSLocalizedString("alert.message.theme-data-corrupted.%@", comment: "Error message when theme data is corrupted. The variable is a description provided by Apple. In English, the message is: This theme cannot be used because of data corruption in the Info.plist. %@.")
				informativeText = NSString.localizedStringWithFormat(localizedError as NSString, debugDescription) as String
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
				
			default:
				informativeText = error.localizedDescription
				presentError(title: errorTitle, message: informativeText, dismiss: dismiss)
			}
		} else if let accountError = error as? AccountError {
			presentError(title: accountError.errorTitle, message: accountError.localizedDescription)
		} else {
			let errorTitle = NSLocalizedString("alert.title.error", comment: "Error")
			presentError(title: errorTitle, message: error.localizedDescription, dismiss: dismiss)
		}
	}

}
