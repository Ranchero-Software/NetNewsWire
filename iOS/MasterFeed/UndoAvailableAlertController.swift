//
//  UndoAvailableAlertController.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

struct UndoAvailableAlertController {
			
	static func alert(handler: @escaping (UIAlertAction) -> Void) -> UIAlertController {
		let title = NSLocalizedString("Undo Available", comment: "Undo Available")
		let message = NSLocalizedString("You can undo this and other actions with a three finger swipe to the left.",
										comment: "Mark all articles")
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let confirmTitle = NSLocalizedString("Got It", comment: "Got It")
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		let markAction = UIAlertAction(title: confirmTitle, style: .default, handler: handler)
		
		alertController.addAction(cancelAction)
		alertController.addAction(markAction)
		
		return alertController
	}
	
}
