//
//  AddFeedWIndowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/21/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

enum AddFeedWindowControllerType {
	case webFeed
	case redditFeed
	case twitterFeed
}

protocol AddFeedWindowControllerDelegate: AnyObject {

	// userEnteredURL will have already been validated and normalized.
	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)
	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController)
	
}

protocol AddFeedWindowController {

	var window: NSWindow? { get }
	func runSheetOnWindow(_ hostWindow: NSWindow)
	
}
