//
//  MarkArticlesReadAlertControllerr.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

struct MarkArticlesReadAlertController {
		
	static func allArticlesAlert(handler: @escaping (UIAlertAction) -> Void) -> UIAlertController {
		let message = NSLocalizedString("Mark all articles in all accounts as read?",
										comment: "Mark all articles")
		return markAllReadAlert(message: message, handler: handler)
	}
	
	static func timelineArticlesAlert(handler:  @escaping (UIAlertAction) -> Void) -> UIAlertController {
		let message = NSLocalizedString("Mark all articles in this timeline as read?",
										comment: "Mark all articles")
		return markAllReadAlert(message: message, handler: handler)
	}
	
	// MARK: -
	
	private static func markAllReadAlert(message: String,
										 handler: @escaping (UIAlertAction) -> Void) -> UIAlertController {
		let title = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let markTitle = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		let markAction = UIAlertAction(title: markTitle, style: .default, handler: handler)
		
		alertController.addAction(cancelAction)
		alertController.addAction(markAction)
		
		return alertController
	}
	
}
