//
//  AddFeedWIndowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/21/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

protocol AddFeedWindowControllerDelegate: class {

	// userEnteredURL will have already been validated and normalized.
	func addFeedWindowController(_: AddWebFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)
	func addFeedWindowControllerUserDidCancel(_: AddWebFeedWindowController)
	
}

protocol AddFeedWindowController {

	var window: NSWindow? { get }
	func runSheetOnWindow(_ hostWindow: NSWindow)
	
}
