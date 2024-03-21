//
//  UIViewController-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(iOS)
import UIKit
import SwiftUI

extension UIViewController {

	// MARK: Error Handling

	public func presentError(title: String, message: String, dismiss: (() -> Void)? = nil) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let dismissTitle = NSLocalizedString("OK", comment: "OK")
		let dismissAction = UIAlertAction(title: dismissTitle, style: .default) { _ in
			dismiss?()
		}
		alertController.addAction(dismissAction)
		self.present(alertController, animated: true, completion: nil)
	}
	
}
#endif
