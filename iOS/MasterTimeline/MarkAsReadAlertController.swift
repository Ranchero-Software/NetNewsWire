//
//  UndoAvailableAlertController.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

protocol MarkAsReadAlertControllerSourceType {}
extension CGRect: MarkAsReadAlertControllerSourceType {}
extension UIView: MarkAsReadAlertControllerSourceType {}
extension UIBarButtonItem: MarkAsReadAlertControllerSourceType {}


struct MarkAsReadAlertController {
	
	static func confirm<T>(_ controller: UIViewController?,
						   coordinator: SceneCoordinator?,
						   confirmTitle: String,
						   sourceType: T,
						   cancelCompletion: (() -> Void)? = nil,
						   completion: @escaping () -> Void) where T: MarkAsReadAlertControllerSourceType {
		
		guard let controller = controller, let coordinator = coordinator else {
			completion()
			return
		}
		
		if AppDefaults.shared.confirmMarkAllAsRead {
			let alertController = MarkAsReadAlertController.alert(coordinator: coordinator, confirmTitle: confirmTitle, cancelCompletion: cancelCompletion, sourceType: sourceType) { _ in
				completion()
			}
			controller.present(alertController, animated: true)
		} else {
			completion()
		}
	}
	
	private static func alert<T>(coordinator: SceneCoordinator,
							  confirmTitle: String,
							  cancelCompletion: (() -> Void)?,
							  sourceType: T,
							  completion: @escaping (UIAlertAction) -> Void) -> UIAlertController where T: MarkAsReadAlertControllerSourceType  {
		
		
		let title = NSLocalizedString("Mark As Read", comment: "Mark As Read")
		let message = NSLocalizedString("You can turn this confirmation off in settings.",
										comment: "You can turn this confirmation off in settings.")
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let settingsTitle = NSLocalizedString("Open Settings", comment: "Open Settings")
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
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
		
		if let barButtonItem = sourceType as? UIBarButtonItem {
			alertController.popoverPresentationController?.barButtonItem = barButtonItem
		}
		
		if let rect = sourceType as? CGRect {
			alertController.popoverPresentationController?.sourceRect = rect
		}
		
		if let view = sourceType as? UIView {
			alertController.popoverPresentationController?.sourceView = view
		}

		return alertController
	}
	
}
