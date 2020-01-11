//
//  UndoAvailableAlertController.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

struct MarkAsReadAlertController {
	
	static func confirm(_ controller: UIViewController?,
						coordinator: SceneCoordinator?,
						confirmTitle: String,
						cancelCompletion: (() -> Void)? = nil,
						completion: @escaping () -> Void) {
		
		guard let controller = controller, let coordinator = coordinator else {
			completion()
			return
		}
		
		if AppDefaults.confirmMarkAllAsRead {
			let alertController = MarkAsReadAlertController.alert(coordinator: coordinator, confirmTitle: confirmTitle, cancelCompletion: cancelCompletion) { _ in
				completion()
			}
			controller.present(alertController, animated: true)
		} else {
			completion()
		}
	}
	
	private static func alert(coordinator: SceneCoordinator,
							  confirmTitle: String,
							  cancelCompletion: (() -> Void)?,
							  completion: @escaping (UIAlertAction) -> Void) -> UIAlertController {
		
		let title = NSLocalizedString("Mark As Read", comment: "Mark As Read")
		let message = NSLocalizedString("You can turn this confirmation off in settings.",
										comment: "You can turn this confirmation off in settings.")
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let settingsTitle = NSLocalizedString("Open Settings", comment: "Open Settings")
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
			cancelCompletion?()
		}
		let settingsAction = UIAlertAction(title: settingsTitle, style: .default) { _ in
			coordinator.showSettings(scrollToArticlesSection: true)
		}
		let markAction = UIAlertAction(title: confirmTitle, style: .default, handler: completion)
		
		alertController.addAction(markAction)
		alertController.addAction(settingsAction)
		alertController.addAction(cancelAction)

		return alertController
	}
	
}
