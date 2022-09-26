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
		
		
		let title = NSLocalizedString("Mark as Read", comment: "Catch Up")
		let message = NSLocalizedString("Mark articles as read older than",
										comment: "Mark articles as read older than")
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
			cancelCompletion?()
		}
		let oneDayAction = UIAlertAction(title: "1 Day", style: .default, handler: completion)
		let twoDaysAction = UIAlertAction(title: "2 Days", style: .default, handler: completion)
		let threeDaysAction = UIAlertAction(title: "3 Days", style: .default, handler: completion)
		let oneWeekAction = UIAlertAction(title: "1 Week", style: .default, handler: completion)
		let twoWeeksAction = UIAlertAction(title: "2 Weeks", style: .default, handler: completion)
		let oneMonthAction = UIAlertAction(title: "1 Month", style: .default, handler: completion)
		let oneYearAction = UIAlertAction(title: "1 Year", style: .default, handler: completion)
		
		alertController.addAction(oneDayAction)
		alertController.addAction(twoDaysAction)
		alertController.addAction(threeDaysAction)
		alertController.addAction(oneWeekAction)
		alertController.addAction(twoWeeksAction)
		alertController.addAction(oneMonthAction)
		alertController.addAction(oneYearAction)
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
