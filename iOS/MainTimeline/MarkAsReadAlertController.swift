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

@MainActor struct MarkAsReadAlertController {

	static func confirm<T>(_ controller: UIViewController?,
	                       confirmTitle: String,
	                       sourceType: T,
	                       cancelCompletion: (() -> Void)? = nil,
	                       completion: @escaping () -> Void) where T: MarkAsReadAlertControllerSourceType {

		guard let controller else {
			completion()
			return
		}

		if AppDefaults.confirmMarkAllAsRead {
			let alertController = MarkAsReadAlertController.alert(confirmTitle: confirmTitle, cancelCompletion: cancelCompletion, sourceType: sourceType) { _ in
				completion()
			}
			controller.present(alertController, animated: true)
		} else {
			completion()
		}
	}

	private static func alert<T>(confirmTitle: String,
	                             cancelCompletion: (() -> Void)?,
	                             sourceType: T,
	                             completion: @escaping (UIAlertAction) -> Void) -> UIAlertController where T: MarkAsReadAlertControllerSourceType {

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")

		let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
			cancelCompletion?()
		}
		let markAction = UIAlertAction(title: confirmTitle, style: .default, handler: completion)

		alertController.addAction(markAction)
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
